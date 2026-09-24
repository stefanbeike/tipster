export async function prepareProfileImage(file: File): Promise<string> {
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) throw new Error('Bitte wähle ein JPG-, PNG- oder WebP-Bild.')
  if (file.size > 5 * 1024 * 1024) throw new Error('Das Profilbild darf maximal 5 MB groß sein.')
  const url = URL.createObjectURL(file)
  try {
    const image = new Image()
    await new Promise<void>((resolve, reject) => { image.onload = () => resolve(); image.onerror = () => reject(new Error('Das Bild konnte nicht gelesen werden.')); image.src = url })
    const canvas = document.createElement('canvas'); canvas.width = 256; canvas.height = 256
    const context = canvas.getContext('2d')
    if (!context) throw new Error('Das Bild konnte nicht verarbeitet werden.')
    const side = Math.min(image.naturalWidth, image.naturalHeight)
    context.fillStyle = '#ffffff'; context.fillRect(0, 0, 256, 256)
    context.drawImage(image, (image.naturalWidth - side) / 2, (image.naturalHeight - side) / 2, side, side, 0, 0, 256, 256)
    return canvas.toDataURL('image/jpeg', 0.85)
  } finally { URL.revokeObjectURL(url) }
}
