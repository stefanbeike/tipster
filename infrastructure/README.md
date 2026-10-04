# AWS-Deployment vorbereiten

**Status: ausschließlich lokale Vorbereitung. Kein Apply, keine AWS-Ressourcen
angelegt und kein bestehendes Deployment verändert.** Jede spätere AWS-Änderung
benötigt eine ausdrückliche Freigabe, auch Image-Pushes, Secret-Befüllung,
Datenbankinitialisierung, DNS-Änderungen und das Starten von Tasks.

## Bestehende Anwendung

| Bereich | Bestand |
| --- | --- |
| Build | Gradle-Monorepo, Java-Toolchain 21, Micronaut 4.10.17 |
| User-Service | Port 8081, Hibernate/JPA, JWT, JavaMail, Liquibase |
| Payment-Service | Port 8082, Stripe HTTP-Integration, JWT, Liquibase |
| Frontend | React 19, TypeScript 5.9, Vite 7; Node-Build und Nginx-Runtime |
| Datenbank | PostgreSQL 15, Datenbank `tipsterdb`, Schemas `user_mgmt` / `payment_mgmt` |
| Lokales Compose | PostgreSQL, MailHog, MinIO und optional Stripe CLI |
| Bisheriges AWS-CI | ECR/ECS-Jobs, teilweise Region eu-north-1 und AWS-Key-Secrets |

Die Anwendung speichert Profilbilder in PostgreSQL; eine aktive S3-Anbindung
ist im Anwendungscode nicht vorhanden. MinIO und MailHog werden daher nicht
nach AWS übernommen. E-Mail wird über Amazon SES in Frankfurt auf Port 587
mit STARTTLS versendet. Terraform verwaltet die SES-Domain und die zugehörigen
DNS-Einträge in der vorhandenen öffentlichen Route-53-Zone.

## Architektur und Grenzen

Terraform beschreibt eine **neue, separate** Umgebung in `eu-central-1`:

- VPC `10.42.0.0/16`, zwei Availability Zones, öffentliche/private Subnetze,
  je AZ ein NAT-Gateway für Stripe, SMTP, Images und AWS-Endpunkte.
- Öffentlicher Application Load Balancer: HTTP leitet auf HTTPS um;
  ein bereits ausgestelltes ACM-Zertifikat in Frankfurt wird per ARN referenziert.
- Ein privater ECS-Fargate-Service mit drei Containern pro Task. Nginx verbindet
  sich über `127.0.0.1` mit den beiden Backends. Alle drei Container skalieren
  gemeinsam; bei später nötiger unabhängiger Skalierung ist die Aufteilung
  in Services mit Service Connect oder Service Discovery erforderlich.
- Private, verschlüsselte RDS-PostgreSQL-15-Datenbank, zum Einstieg `db.t4g.micro` und Single-AZ,
  14 Tage Backups und Löschschutz. Das Master-Passwort erzeugt und verwaltet
  RDS in Secrets Manager, ohne es an Terraform zu geben.
- Getrennte DB-Benutzer und Schema-Eigentümer für die Backends. Liquibase
  benötigt Schema-Eigentümerrechte, aber keine RDS-Administratorrechte. Die
  bestehende Payment-Migration enthält `CREATE SCHEMA IF NOT EXISTS`; deshalb
  erhält nur `tipster_payment` zusätzlich `CREATE` auf der Anwendungsdatenbank.
- Drei ECR-Repositories mit unveränderlichen Tags und Image-Scanning,
  CloudWatch-Logs mit 30 Tagen Aufbewahrung, ECS-Deployment-Rollback.
- Ein leeres Secrets-Manager-Secret für Anwendungskonfiguration. Terraform
  speichert nur ARNs und JSON-Feldnamen, niemals Secret-Versionen oder Werte.

`desired_count = 0` verhindert den Anwendungsstart beim späteren Bootstrap.
**Ein Apply würde trotzdem kostenpflichtige Infrastruktur anlegen**, insbesondere
zwei NAT-Gateways, ALB und RDS. Für verfügbare Produktion später mindestens zwei
Tasks einplanen. Kapazitäten und Kosten müssen vor Freigabe geprüft werden.

Web-DNS und Zertifikatausstellung, WAF, Alarme, Restore-Tests, Datenmigration und
Stripe-Konfiguration sind separate Betriebsaufgaben. Bestehende Ressourcen
werden weder automatisch importiert noch ersetzt. Vor einem späteren Plan
Bestand/Namenskonflikte prüfen: z. B. Cluster `gratilo-prd-iac`, ECR-Präfix
`tipster-prd/`, Datenbank und Load Balancer `tipster-prd`. Für eine Übernahme
bestehender Ressourcen ist ein gesonderter Import-/Migrationsplan nötig.

## Dateien

- `versions.tf`, `.terraform.lock.hcl`: Terraform-/Provider-Versionen.
- `providers.tf`: Region, Account-Prüfung, Tags; keine Zugangsdaten.
- `variables.tf`, `terraform.tfvars.example`: ausschließlich nicht geheime Eingaben.
- `main.tf`: Netzwerk, Datenbank, Secret-Hülle, ECR, Logs, ALB.
- `ecs.tf`: Rollen, Task-Definitionen und Service; Terraform startet keinen DB-Job.
- `bootstrap.sql`: Rollen und Schemas für die initial leere Datenbank.
- `ses.tf`: SES-Domain, Route-53-Verifizierung/DKIM/MX/SPF und SMTP-IAM-Benutzer ohne Schlüssel.
- `outputs.tf`: Ressourcenreferenzen, keine Secret-Werte.

## Lokale Vorbereitung und Validierung

Voraussetzungen: Terraform >= 1.10 und < 2, AWS CLI mit lokal eingerichteter
Profil-/SSO-Anmeldung. Auch der GitHub-Runner verwendet ein lokal eingerichtetes AWS-Profil.
Keine AWS-Zugangsdaten in tfvars, `.env.example`, Git,
CI-Secrets oder Terraform hinterlegen. Die bestehende lokale `.env` bleibt
unverändert und wird für Terraform nicht eingelesen.

```bash
cd infrastructure
# Entfernt ggf. geerbte Zugangsdaten nur aus dieser Shell, nicht aus Dateien.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
export AWS_PROFILE=mein-profil
export AWS_REGION=eu-central-1
export AWS_DEFAULT_REGION=eu-central-1

terraform fmt -recursive
# Provider-Download; ohne AWS-Backend und ohne Ressourcenänderungen.
terraform init -backend=false
terraform validate
terraform fmt -check -recursive
```

Für `fmt` und `validate` sind keine AWS-Anmeldung und keine echten Variablenwerte
nötig. Die Provider-Lockdatei gehört in Git, `.terraform/` nicht. Die lokale Prüfung
erfolgt unter Linux/WSL; bei weiteren Plattformen vorab `terraform providers lock`
für die gewünschten Plattformen ausführen und die Lockdatei kontrolliert ergänzen.

Für einen späteren Plan eine neue lokale Variablendatei vorbereiten, ohne eine
bereits vorhandene zu überschreiben:

```bash
cp -n terraform.tfvars.example terraform.tfvars
# In terraform.tfvars: Account-ID, ACM-ARN und gegebenenfalls SES-Absender ersetzen.
# Es werden ausdrücklich KEINE Passwörter/Stripe-Schlüssel eingetragen.
cp -n backend.tfbackend.example backend.tfbackend
# Bestehenden S3-State-Bucket und dessen Account-ID in backend.tfbackend eintragen.
terraform init -backend-config=backend.tfbackend
terraform plan -out=deployment.tfplan
terraform show deployment.tfplan
```

`plan` liest den AWS-Account über das aktive CLI-Profil; es wurde im Rahmen
dieser Vorbereitung nicht ausgeführt. `allowed_account_ids` muss die tatsächliche
Account-ID enthalten. Ein Plan kann lokale State-/Plan-Dateien schreiben, legt
aber keine Infrastruktur an. Lokal gespeicherte Pläne sind zu schützen; der GitHub-Workflow bewahrt seinen
Plan für die Freigabe kurzzeitig als Actions-Artefakt auf.

### State

`backend.tf` verwendet S3 in Frankfurt mit Verschlüsselung und S3-Locking
(`use_lockfile = true`). Der feste State-Key ist `gratilo/prd/terraform.tfstate`.
Bucketname und erwarteter Bucket-Account kommen lokal aus `backend.tfbackend`,
im GitHub-Workflow aus Repository-Variablen. Beide Wege müssen denselben Bucket
und Key verwenden. Es gibt für echte Plans/Applies keinen lokalen State-Fallback.

Der Bucket muss vor dem ersten Workflow separat und ausdrücklich freigegeben
angelegt werden: in `eu-central-1`, privat, versioniert, verschlüsselt, mit
restriktiven Zugriffsrechten. Diese Konfiguration legt den eigenen Backend-Bucket
absichtlich nicht an. Falls bereits lokaler State existiert, diesen sichern und
nach ausdrücklicher Freigabe mit `terraform init -migrate-state
-backend-config=backend.tfbackend` übernehmen, statt einen neuen leeren State
gegen existierende Ressourcen zu verwenden.

`.gitignore` schützt State, Backups, Pläne, lokale tfvars und `*.tfbackend`.
State und gespeicherte Pläne sind sensible Daten. Keine AWS-Keys in
Backend-Dateien oder `-backend-config` übergeben.

## Späteres Deployment — nur nach ausdrücklicher Freigabe

Der folgende Befehl ist dokumentiert, **nicht ausgeführt**:

```bash
# Erst nach Prüfung und ausdrücklicher Freigabe genau dieses Plans:
terraform apply deployment.tfplan
```

Ein gespeicherter Plan wird ohne weitere CLI-Rückfrage angewendet; deshalb ist
die vorherige Freigabe entscheidend. Bei Änderungen oder länger zurückliegendem Plan neu planen
und den neuen Plan erneut prüfen. RDS besitzt zusätzlich Terraform-`prevent_destroy`
und AWS-Löschschutz; der ALB besitzt AWS-Löschschutz.

Die Reihenfolge nach einer separat genehmigten Infrastruktur-Erstellung:

1. `desired_count = 0` beibehalten. Outputs erfassen. DNS noch nicht umschalten.
2. Secret `application_secret_arn` über einen freigegebenen sicheren Weg befüllen.
   Erwartete JSON-Feldnamen: `jwt_secret`, `internal_api_key`,
   `user_db_password`, `payment_db_password`, `smtp_username`, `smtp_password`,
   `stripe_secret_key`, `stripe_webhook_secret`.
   JWT-Schlüssel ausreichend zufällig mit mindestens 32 Bytes wählen;
   beide Services erhalten denselben JWT- und internen API-Schlüssel.
   Stripe zunächst im Sandbox-Modus belassen. Keine Werte in Shell-History,
   JSON-Dateien im Repository, Terraform-Variablen oder Docker-Build-Argumenten
   speichern. Kein `aws_secretsmanager_secret_version` und keine Secret-Data-Source
   ergänzen: diese würden Werte in den Terraform-State übernehmen.
3. Images lokal für `linux/amd64` bauen und nach gesonderter Freigabe in die
   ausgegebenen ECR-Repositories pushen. Beispiel für reine lokale Builds:

   ```bash
   docker build --platform linux/amd64 -f backend/user-service/Dockerfile -t tipster-user:initial .
   docker build --platform linux/amd64 -f backend/payment-service/Dockerfile -t tipster-payment:initial .
   docker build --platform linux/amd64 \
     --build-arg VITE_STRIPE_PUBLISHABLE_KEY="$STRIPE_PUBLISHABLE_KEY" \
     -t tipster-frontend:initial ./frontend
   ```

   Diese Build-Befehle gelten vom Repository-Stamm aus. Der Stripe-Publishable-Key
   ist öffentlich und wird in das Frontend eingebaut; niemals Secret-/Webhook-Keys
   als Build-Argumente verwenden. ECR-Login und Push erfolgen später ausschließlich
   über die lokale AWS-CLI-Anmeldung. Jeder Release braucht einen neuen Tag;
   denselben Tag für alle drei Images und `image_tag` verwenden.
4. Nach ausdrücklicher Freigabe genau eine Task mit
   `bootstrap_task_definition_arn` im ausgegebenen Cluster starten. Die
   `bootstrap_network_configuration` aus den Outputs unverändert verwenden
   (private Subnetze, keine öffentliche IP). Auf Ende warten, Exit-Code 0 und
   Logs kontrollieren. Die Task nutzt RDS-Adminrechte nur zur Einrichtung von
   `tipster_user`, `tipster_payment` und ihren Schemas. Sie ist für eine neue
   Datenbank vorgesehen, übernimmt keine Daten oder abweichenden Schema-Owner.
   PostgreSQL-15-Client aus Public ECR wird über NAT geladen; für reproduzierbare
   Produktionsfreigaben den geprüften Image-Digest festschreiben.
5. `desired_count` auf 1 für die erste Prüfung bzw. 2 für verfügbare Produktion
   setzen, neuen Plan prüfen und nur mit erneuter Freigabe anwenden. Liquibase
   migriert beim Start. ECS- und ALB-Health prüfen. DNS kontrolliert zum ALB
   umstellen; ACM-Zertifikat muss zum öffentlichen Host passen.
6. Registrierung/E-Mail, Login, Passwort-Reset, Stripe-Sandbox-Checkout und
   signierte Webhooks prüfen. Stripe-Webhook:
   `https://<domain_name>/payment-service/webhooks/stripe`.
   Bestehende Produktionsdaten benötigen vorher einen eigenen Migrationsplan.

Geänderte Secret-Werte gelangen erst mit neuen Tasks in die Anwendung. Für
Passwortrotation der beiden App-DB-Benutzer zuerst einen koordinierten Ablauf
mit DB-Änderung und Task-Neustart freigeben; die Bootstrap-Task nicht unkoordiniert
im laufenden Betrieb wiederholen. Die automatische Rotation des RDS-Admin-Secrets
betrifft die App-Benutzer nicht.

## Minimale Änderungen am Bestand

Nginx lädt seine Konfiguration jetzt über den Template-Mechanismus des offiziellen
Images. Standardhosts bleiben `user-service` und `payment-service` für Compose;
Fargate setzt beide auf `127.0.0.1`. Java-/React-Geschäftslogik bleibt unverändert.
Docker-Kontexte schließen `.env` und Terraform-/Credential-Artefakte aus.

Die bisherigen ECR-Publish-Jobs sind gesperrt, ECS-Deployment ist deaktiviert und
die Konfiguration statischer AWS-Key-Secrets wurde aus den Workflows entfernt.
PR-Image-Builds ohne Push bleiben nutzbar. Regionsvorgaben sind auf `eu-central-1`
vereinheitlicht. Es wurde kein Workflow gestartet. Diese alten Publish-/Deploy-Jobs bleiben gesperrt. Der neue, ausschließlich
manuell gestartete Terraform-Workflow ist unten beschrieben.

Die bereinigte `.env.example` enthält nur Platzhalter. Bereits früher eingecheckte
Schlüssel bleiben möglicherweise in der alten Git-Historie: Betroffene Stripe-
und Webhook-Schlüssel müssen separat rotiert werden. Eine erneute History-Umschreibung
oder Schlüsselrotation gehört nicht zu dieser Infrastruktur-Vorbereitung.

## Referenzen

- [Fargate-Netzwerk: Container einer Task kommunizieren über localhost](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-networking.html)
- [Secrets Manager zur Laufzeit in ECS injizieren](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/secrets-envvar-secrets-manager.html)
- [RDS-Provider: manage_master_user_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)
- [Terraform S3-Backend und State-Locking](https://developer.hashicorp.com/terraform/language/backend/s3)

## Lokaler Prüfstand

Geprüft mit Terraform 1.13.5 und AWS-Provider 6.67.0 unter Linux/WSL:
`terraform fmt -check -recursive` und `terraform validate` erfolgreich.
Provider-Installation erfolgte mit `init -backend=false`; der Download wurde
gegen die offizielle SHA-256-Prüfsumme geprüft. Die Lockdatei enthält zunächst
den Linux-amd64-Hash. Nginx-Syntax und die unveränderten Compose-Standardhosts
wurden geprüft; die DB-Initialisierung wurde mit getrennten Rollen einschließlich
einer Wiederholung in einem isolierten PostgreSQL-15-Container getestet.
AWS-Plan, Apply und End-to-End-Tests in AWS wurden nicht ausgeführt.


## GitHub Actions: Infrastruktur anlegen und aktualisieren

Workflow: `.github/workflows/terraform.yml`, **Terraform AWS Infrastructure**.
Kein Push-, PR- oder Zeitplan-Trigger: nur `workflow_dispatch` auf `main`.
Der Workflow wurde hier weder gestartet noch in GitHub konfiguriert.

### Einmalige Voraussetzungen

1. Einen vertrauenswürdigen, dedizierten Linux-x64-Self-hosted-Runner mit Labels
   `self-hosted`, `linux`, `x64`, `terraform` bereitstellen. Er braucht AWS CLI,
   Python 3, Netzwerkzugriff für Terraform und ein gültiges lokales AWS-Profil
   unter dem Runner-Benutzer. Er darf keine fremden PR-Jobs ausführen und soll
   einen eigenen Actions-Workspace verwenden, nicht den lokalen Entwicklungsordner.
   Bei SSO muss die Anmeldung auch während eines späteren Apply gültig sein.
   Es werden keine AWS-Access-Keys in GitHub Secrets oder YAML verwendet.
2. Den oben beschriebenen S3-State-Bucket separat bereitstellen. Das Profil
   benötigt `s3:ListBucket`, `s3:GetObject`/`s3:PutObject` auf den State-Key sowie
   `s3:GetObject`/`s3:PutObject`/`s3:DeleteObject` auf dessen `.tflock`-Objekt.
   Bei einem eigenen KMS-Schlüssel sind zusätzlich passende KMS-Rechte nötig.
   Hinzu kommen die kontrollierten Provisionierungsrechte für die in Terraform
   definierten Dienste einschließlich SES und Route-53-Datensätzen, IAM-Rollen inklusive `iam:PassRole` und gegebenenfalls
   Service-linked Roles. Keine pauschale Administratorfreigabe im Workflow.
3. Repository-Variablen in **Settings → Secrets and variables → Actions → Variables**:

   | Variable | Inhalt |
   | --- | --- |
   | `TERRAFORM_AWS_PROFILE` | Name des lokalen AWS-CLI-Profils auf dem Runner |
   | `AWS_ACCOUNT_ID` | Erwartete zwölfstellige Ziel-Account-ID |
   | `TERRAFORM_STATE_BUCKET` | Bereits existierender S3-State-Bucket |
   | `TERRAFORM_CERTIFICATE_ARN` | Ausgestelltes ACM-Zertifikat für gratilo.com in eu-central-1 |
   | `TERRAFORM_MAIL_FROM_EMAIL` | Optional: Absender in gratilo.com, Standard noreply@gratilo.com |

   Das sind Konfigurationswerte, keine Secret-Inhalte. Stripe-, SMTP- und
   DB-Passwörter bleiben in Secrets Manager und werden nicht an den Workflow
   übergeben. Das lokale Profil wird anhand der Account-ID geprüft; geerbte
   AWS-Key-Umgebungsvariablen werden für die Terraform-Schritte geleert.
4. **Vor dem ersten Apply** unter **Settings → Environments** die Environment
   `terraform-prd` anlegen, **Required reviewers** aktivieren und Deployments
   auf `main` begrenzen. Die Workflow-Datei kann diese GitHub-Schutzregeln nicht
   selbst einschalten. Ohne diese Einstellung wartet GitHub nicht auf eine
   zusätzliche Plan-Freigabe. Falls der GitHub-Tarif diese Schutzregel nicht
   unterstützt, nur `plan` verwenden und einen geprüften Plan lokal freigeben.

### Ablauf

- In **Actions → Terraform AWS Infrastructure → Run workflow** zunächst
  `operation=plan` wählen. Der Job prüft Format/Validität und erstellt einen
  gespeicherten Plan. Er stellt die Infrastruktur nicht bereit; S3-Locking
  schreibt während des Plans lediglich ein temporäres Lockobjekt.
- Für ein Deployment `operation=apply` und als Bestätigung exakt
  `APPLY gratilo-prd-iac` eingeben. Auch dann läuft zuerst der Plan-Job.
  Anschließend das Artefakt herunterladen und `deployment-plan.txt` prüfen;
  erst danach den Apply-Job in `terraform-prd` freigeben.
- Der Apply-Job verwendet denselben Commit, denselben State-Bucket/Key und
  **genau die gespeicherte Plan-Datei**. Es gibt kein erneutes, ungeprüftes Planen
  im Apply-Job. S3-Locking und Workflow-Concurrency verhindern konkurrierende
  Änderungen; laufende Applies werden nicht automatisch abgebrochen.
- Plan-Artefakte enthalten Infrastrukturinformationen und werden nur einen Tag
  gespeichert. Zugriff auf Actions-Artefakte entsprechend beschränken. Nach
  Ablauf oder bei veraltetem State einen neuen Workflow samt Freigabe starten.
  Plan-Dateien werden nach dem Job vom persistenten Runner entfernt.
- Beim ersten Lauf `desired_count=0` lassen. Vor späteren Updates den aktuellen
  `image_tag` und die gewünschte Task-Anzahl ausdrücklich auswählen: die
  Eingaben sind Sollwerte, nicht automatisch aus AWS gelesene Bestandswerte.
  Ein erneutes `0` würde den Service auf null Tasks skalieren.

PostgreSQL verwendet zunächst `db.t4g.micro` (2 vCPUs, 1 GiB RAM), 20 GiB gp3
und Single-AZ. Das ist eine kleine Einstiegskonfiguration ohne Standby-Knoten;
Last und Verbindungen müssen beobachtet werden. `db_multi_az=true` aktiviert
später einen zweiten Knoten über einen neuen geprüften Plan. RDS kann bestimmte
Änderungen wegen `apply_immediately=false` erst im Wartungsfenster umsetzen.
Die beiden NAT-Gateways, ALB und übrigen Ressourcen verursachen weiterhin Kosten.

[Instanzgrößen laut AWS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.Summary.html).


## SES und die bestehende Route-53-Zone

`ses.tf` sucht die bestehende **öffentliche** Zone mit dem Namen `domain_name`
(Standard `gratilo.com`) im angemeldeten AWS-Account. Es wird keine neue Zone
angelegt. Vor Apply prüfen, dass diese Zone tatsächlich öffentlich delegiert ist.
Bei mehreren gleichnamigen öffentlichen Zonen muss zuerst die richtige Zone
identifiziert werden. Bestehende SES-Identitäten oder gleichnamige DNS-Einträge
müssen vor einer Übernahme geprüft und gegebenenfalls ausdrücklich importiert
werden; `allow_overwrite = false` verhindert ungeprüftes Überschreiben.

Ein genehmigtes Apply würde folgende Versand-Konfiguration erstellen:

- SES-Domain-Identität in `eu-central-1`, TXT-Verifizierung unter `_amazonses`
  und drei Easy-DKIM-CNAMEs. Die Domain-Verifizierung wird abgewartet.
- Eigene MAIL-FROM-Subdomain `bounce.gratilo.com` mit SES-MX und SPF-TXT.
  Bei ungültigem MAIL-FROM-MX wird der Versand abgewiesen statt auf eine andere
  MAIL-FROM-Domain zurückzufallen. Vor App-Start auch DKIM und MAIL-FROM-Status
  in SES kontrollieren, da DNS-Propagation noch dauern kann.
- Dedizierter IAM-Benutzer `gratilo-prd-ses-smtp` mit `ses:SendRawEmail`, beschränkt
  auf diese Domain-Identität und die konfigurierte Absenderadresse.
- Der User-Service nutzt `email-smtp.eu-central-1.amazonaws.com:587` mit
  verpflichtendem STARTTLS. Standardabsender ist `noreply@gratilo.com`.

Terraform erzeugt **keine IAM-Access-Keys oder SMTP-Passwörter**. Nach gesonderter
Freigabe müssen für den ausgegebenen SMTP-IAM-Benutzer regionale SES-SMTP-
Zugangsdaten außerhalb Terraform erstellt und als `smtp_username` und
`smtp_password` im vorhandenen Anwendungs-Secret hinterlegt werden. Ein normales
AWS Secret Access Key ist nicht direkt das SMTP-Passwort; die offizielle
SES-Anleitung beschreibt die regionale Ableitung. Keine Zugangsdaten in Git,
Terraform, Workflow-Variablen, `.env.example` oder Chat kopieren. Die CLI-/CI-
Anmeldung für Infrastruktur bleibt unabhängig davon beim lokalen `AWS_PROFILE`.

Die SES-Sandbox wird durch Domain-Verifizierung nicht aufgehoben. Vor Versand
an beliebige Empfänger muss Produktionszugriff für Frankfurt beantragt und von
AWS genehmigt werden. Bis dahin nur mit verifizierten Empfängern testen. SES ist
hier ausschließlich für ausgehende Anwendungsmails vorgesehen: Es wird kein
Postfach angelegt, und MX/SPF/DMARC der Hauptdomain sowie Web-DNS werden nicht
überschrieben. Vor Produktivstart vorhandene DMARC-Regeln und die Verarbeitung
von Bounces/Complaints prüfen; diese Konfiguration erzeugt noch keine automatische
Bounce-/Complaint-Verarbeitung in der Anwendung.

- [SES-SMTP-Zugangsdaten](https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html)
- [Eigene MAIL-FROM-Domain](https://docs.aws.amazon.com/ses/latest/dg/mail-from.html)
