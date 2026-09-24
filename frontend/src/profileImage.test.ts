import { expect, it } from 'vitest'
import { prepareProfileImage } from './profileImage'
it('rejects unsupported file types before decoding', async () => {
  await expect(prepareProfileImage(new File(['<svg/>'], 'image.svg', { type: 'image/svg+xml' }))).rejects.toThrow('JPG-, PNG- oder WebP')
})
it('rejects files larger than 5 MB', async () => {
  await expect(prepareProfileImage(new File([new Uint8Array(5 * 1024 * 1024 + 1)], 'large.jpg', { type: 'image/jpeg' }))).rejects.toThrow('maximal 5 MB')
})
