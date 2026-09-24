import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { App } from './App'
const fetchMock = vi.fn()
beforeEach(() => { history.replaceState({}, '', '/login'); vi.stubGlobal('fetch', fetchMock); fetchMock.mockReset() })
afterEach(() => { cleanup(); vi.unstubAllGlobals() })
function fill(label: string, value: string) { fireEvent.change(screen.getByLabelText(label), { target: { value } }) }
function respond(data: unknown, status = 200) { return { ok: status >= 200 && status < 300, status, json: async () => data } }
describe('authentication', () => {
  it('logs in with the API and fetches the profile using the bearer token', async () => {
    fetchMock.mockResolvedValueOnce(respond({ accessToken: 'jwt-token', email: 'alex@example.com', userId: '123' })).mockResolvedValueOnce(respond({ email: 'alex@example.com' }))
    render(<App />); fill('E-Mail-Adresse', 'alex@example.com'); fill('Passwort', 'Secret!1')
    fireEvent.click(screen.getByRole('button', { name: 'Anmelden' }))
    expect(await screen.findByText('Deine Transaktionen')).toBeInTheDocument()
    expect(fetchMock).toHaveBeenNthCalledWith(2, '/user-service/users/me', expect.objectContaining({ headers: { Authorization: 'Bearer jwt-token' } }))
    fireEvent.click(screen.getByRole('button', { name: 'Abmelden' }))
    expect(screen.getByRole('button', { name: 'Anmelden' })).toBeInTheDocument()
  })
  it('shows failed login errors', async () => {
    fetchMock.mockResolvedValueOnce(respond(null, 401)); render(<App />)
    fill('E-Mail-Adresse', 'alex@example.com'); fill('Passwort', 'wrong'); fireEvent.click(screen.getByRole('button', { name: 'Anmelden' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('E-Mail oder Passwort ist nicht korrekt.')
  })
  it('registers with matching passwords and consent, handling an empty 201 response', async () => {
    history.replaceState({}, '', '/register'); fetchMock.mockResolvedValueOnce(respond(null, 201)); render(<App />)
    fill('E-Mail-Adresse', 'alex@example.com'); fill('Passwort', 'Secret!1'); fill('Passwort wiederholen', 'Secret!1'); fireEvent.click(screen.getByLabelText(/Ich akzeptiere/))
    fireEvent.click(screen.getByRole('button', { name: 'Konto erstellen' }))
    expect(await screen.findByRole('status')).toHaveTextContent('bestätige deine E-Mail-Adresse')
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toMatchObject({ email: 'alex@example.com', confirmPassword: 'Secret!1', agbFileName: 'agb-demo-v1', newsletter: false })
  })
  it('rejects mismatched passwords locally', () => {
    history.replaceState({}, '', '/reset-password?token=test'); render(<App />)
    fill('Neues Passwort', 'Secret!1'); fill('Passwort wiederholen', 'Other!123'); fireEvent.click(screen.getByRole('button', { name: 'Passwort speichern' }))
    expect(screen.getByRole('alert')).toHaveTextContent('stimmen nicht überein'); expect(fetchMock).not.toHaveBeenCalled()
  })
  it('requests a reset link', async () => {
    history.replaceState({}, '', '/forgot-password'); fetchMock.mockResolvedValueOnce(respond({ message: 'Falls die E-Mail-Adresse existiert, wurde ein Link versendet' })); render(<App />)
    fill('E-Mail-Adresse', 'alex@example.com'); fireEvent.click(screen.getByRole('button', { name: 'Link anfordern' }))
    expect(await screen.findByRole('status')).toHaveTextContent('Falls die E-Mail-Adresse existiert')
    expect(fetchMock).toHaveBeenCalledWith('/user-service/auth/password-reset/request', expect.objectContaining({ body: JSON.stringify({ email: 'alex@example.com' }) }))
  })
  it('sends the reset token and clears it from the URL', async () => {
    history.replaceState({}, '', '/reset-password?token=reset-token'); fetchMock.mockResolvedValueOnce(respond({ message: 'Passwort geändert' })); render(<App />)
    fill('Neues Passwort', 'Secret!1'); fill('Passwort wiederholen', 'Secret!1'); fireEvent.click(screen.getByRole('button', { name: 'Passwort speichern' }))
    await screen.findByRole('status')
    expect(fetchMock).toHaveBeenCalledWith('/user-service/auth/password-reset/confirm', expect.objectContaining({ body: JSON.stringify({ token: 'reset-token', newPassword: 'Secret!1' }) })); expect(location.search).toBe('')
  })
  it('verifies email on confirmation', async () => {
    history.replaceState({}, '', '/auth/verify?token=email-token'); fetchMock.mockResolvedValueOnce(respond({ message: 'E-Mail-Adresse wurde bestätigt' })); render(<App />)
    expect(fetchMock).not.toHaveBeenCalled(); fireEvent.click(screen.getByRole('button', { name: 'E-Mail jetzt bestätigen' }))
    expect(await screen.findByRole('status')).toHaveTextContent('wurde bestätigt')
    expect(fetchMock).toHaveBeenCalledWith('/user-service/auth/verify?token=email-token', expect.objectContaining({ method: 'GET' }))
  })
})
