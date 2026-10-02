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
nach AWS übernommen. E-Mail benötigt einen externen SMTP-Anbieter auf Port 587
mit STARTTLS. Eine SES-Domain oder deren Freischaltung wird nicht angelegt.

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
- Private, verschlüsselte RDS-PostgreSQL-15-Datenbank, standardmäßig Multi-AZ,
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

DNS und Zertifikatausstellung, WAF, Alarme, Restore-Tests, Datenmigration und
Stripe-Konfiguration sind separate Betriebsaufgaben. Bestehende Ressourcen
werden weder automatisch importiert noch ersetzt. Vor einem späteren Plan
Bestand/Namenskonflikte prüfen: z. B. Cluster `tipster-prd-iac`, ECR-Präfix
`tipster-prd/`, Datenbank und Load Balancer `tipster-prd`. Für eine Übernahme
bestehender Ressourcen ist ein gesonderter Import-/Migrationsplan nötig.

## Dateien

- `versions.tf`, `.terraform.lock.hcl`: Terraform-/Provider-Versionen.
- `providers.tf`: Region, Account-Prüfung, Tags; keine Zugangsdaten.
- `variables.tf`, `terraform.tfvars.example`: ausschließlich nicht geheime Eingaben.
- `main.tf`: Netzwerk, Datenbank, Secret-Hülle, ECR, Logs, ALB.
- `ecs.tf`: Rollen, Task-Definitionen und Service; Terraform startet keinen DB-Job.
- `bootstrap.sql`: Rollen und Schemas für die initial leere Datenbank.
- `outputs.tf`: Ressourcenreferenzen, keine Secret-Werte.

## Lokale Vorbereitung und Validierung

Voraussetzungen: Terraform >= 1.10 und < 2, AWS CLI mit lokal eingerichteter
Profil-/SSO-Anmeldung. Keine AWS-Zugangsdaten in tfvars, `.env.example`, Git,
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
nötig. Die Provider-Lockdatei gehört in Git, `.terraform/` nicht.

Für einen späteren Plan eine neue lokale Variablendatei vorbereiten, ohne eine
bereits vorhandene zu überschreiben:

```bash
cp -n terraform.tfvars.example terraform.tfvars
# In terraform.tfvars: Account-ID, ACM-ARN, SMTP-Host und Absender ersetzen.
# Es werden ausdrücklich KEINE Passwörter/Stripe-Schlüssel eingetragen.
terraform init
terraform plan -out=deployment.tfplan
terraform show deployment.tfplan
```

`plan` liest den AWS-Account über das aktive CLI-Profil; es wurde im Rahmen
dieser Vorbereitung nicht ausgeführt. `allowed_account_ids` muss die tatsächliche
Account-ID enthalten. Ein Plan kann lokale State-/Plan-Dateien schreiben, legt
aber keine Infrastruktur an. Gespeicherte Pläne bleiben lokal und sind zu schützen.

### State

Es ist bewusst kein existierender S3-Bucket angenommen: ohne Backend-Konfiguration
liegt der State lokal. `.gitignore` schützt State, Backups, Pläne und lokale tfvars.
Auch State ohne Passwortwerte enthält sensible Infrastrukturinformationen.
Für dauerhaften/teamweiten Betrieb vor dem ersten Apply einen separaten,
freigegebenen S3-Backend-Bucket mit Verschlüsselung, Versionierung, restriktiven
Rechten und S3-Locking (`use_lockfile = true`) einrichten und das Backend
konfigurieren. Keine AWS-Keys in Backend-Dateien oder `-backend-config` übergeben.
Backend-Erstellung und eine spätere State-Migration sind hier nicht automatisiert.

## Späteres Deployment — nur nach ausdrücklicher Freigabe

Der folgende Befehl ist dokumentiert, **nicht ausgeführt**:

```bash
# Erst nach Prüfung und ausdrücklicher Freigabe genau dieses Plans:
terraform apply deployment.tfplan
```

Kein `-auto-approve`. Bei Änderungen oder länger zurückliegendem Plan neu planen
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
vereinheitlicht. Es wurde kein Workflow gestartet. Diese Sperren nicht ohne
separat genehmigtes Authentifizierungs-/Deployment-Konzept aufheben.

Die bereinigte `.env.example` enthält nur Platzhalter. Bereits früher eingecheckte
Schlüssel bleiben möglicherweise in der alten Git-Historie: Betroffene Stripe-
und Webhook-Schlüssel müssen separat rotiert werden. Eine erneute History-Umschreibung
oder Schlüsselrotation gehört nicht zu dieser Infrastruktur-Vorbereitung.

## Referenzen

- [Fargate-Netzwerk: Container einer Task kommunizieren über localhost](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-task-networking.html)
- [Secrets Manager zur Laufzeit in ECS injizieren](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/secrets-envvar-secrets-manager.html)
- [RDS-Provider: manage_master_user_password](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)
- [Terraform S3-Backend und State-Locking](https://developer.hashicorp.com/terraform/language/backend/s3)
