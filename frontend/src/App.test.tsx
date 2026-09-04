import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { App } from './App'

describe('App', () => {
  it('renders the primary action', () => {
    render(<App />)
    expect(screen.getByRole('button', { name: 'QR-Code scannen' })).toBeInTheDocument()
  })
})
