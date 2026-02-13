/**
 * WAVEFORM GENERATOR
 * Generate visual waveform representations from audio files
 * Used to display voice note previews in cards
 */

/**
 * Generate waveform SVG from audio file
 * @param {string} audioUrl - URL of the audio file
 * @param {Object} options - Waveform options
 * @returns {Promise<string>} SVG string
 */
export async function generateWaveformSVG(audioUrl, options = {}) {
  const {
    width = 300,
    height = 60,
    barCount = 50,
    barGap = 2,
    barColor = '#d4af37',
    barMinHeight = 3,
    barMaxHeight = height * 0.9,
    centerBars = true
  } = options

  try {
    // Fetch and decode audio
    const audioContext = new (window.AudioContext || window.webkitAudioContext)()
    const response = await fetch(audioUrl)
    const arrayBuffer = await response.arrayBuffer()
    const audioBuffer = await audioContext.decodeAudioData(arrayBuffer)

    // Get audio data (use first channel)
    const rawData = audioBuffer.getChannelData(0)
    const samples = barCount

    // Calculate samples per bar
    const blockSize = Math.floor(rawData.length / samples)
    const filteredData = []

    // Get peak values for each bar
    for (let i = 0; i < samples; i++) {
      const blockStart = blockSize * i
      let sum = 0

      // Calculate RMS (root mean square) for this block
      for (let j = 0; j < blockSize; j++) {
        const val = rawData[blockStart + j]
        sum += val * val
      }

      filteredData.push(Math.sqrt(sum / blockSize))
    }

    // Normalize data
    const max = Math.max(...filteredData)
    const normalizedData = filteredData.map(n => n / max)

    // Generate SVG bars
    const barWidth = (width - (barGap * (barCount - 1))) / barCount
    const bars = []

    for (let i = 0; i < normalizedData.length; i++) {
      const barHeight = Math.max(
        barMinHeight,
        normalizedData[i] * barMaxHeight
      )

      const x = i * (barWidth + barGap)
      const y = centerBars ? (height - barHeight) / 2 : height - barHeight

      bars.push(`
        <rect
          x="${x}"
          y="${y}"
          width="${barWidth}"
          height="${barHeight}"
          fill="${barColor}"
          rx="1"
        />
      `)
    }

    // Create SVG
    const svg = `
      <svg
        width="${width}"
        height="${height}"
        viewBox="0 0 ${width} ${height}"
        xmlns="http://www.w3.org/2000/svg"
        preserveAspectRatio="none"
      >
        ${bars.join('')}
      </svg>
    `

    return svg

  } catch (error) {
    console.error('Error generating waveform:', error)
    return generatePlaceholderWaveform(width, height, barColor)
  }
}

/**
 * Generate a placeholder waveform (generic bars)
 * Used when actual audio can't be processed
 */
function generatePlaceholderWaveform(width, height, color) {
  const barCount = 50
  const barGap = 2
  const barWidth = (width - (barGap * (barCount - 1))) / barCount
  const bars = []

  // Generate random-ish heights for visual variety
  for (let i = 0; i < barCount; i++) {
    const barHeight = Math.random() * height * 0.7 + height * 0.1
    const x = i * (barWidth + barGap)
    const y = (height - barHeight) / 2

    bars.push(`
      <rect
        x="${x}"
        y="${y}"
        width="${barWidth}"
        height="${barHeight}"
        fill="${color}"
        opacity="0.5"
        rx="1"
      />
    `)
  }

  return `
    <svg
      width="${width}"
      height="${height}"
      viewBox="0 0 ${width} ${height}"
      xmlns="http://www.w3.org/2000/svg"
      preserveAspectRatio="none"
    >
      ${bars.join('')}
    </svg>
  `
}

/**
 * Generate and inject waveform into DOM element
 * @param {string} audioUrl - URL of the audio file
 * @param {HTMLElement} containerElement - Container to inject waveform into
 * @param {Object} options - Waveform options
 */
export async function injectWaveform(audioUrl, containerElement, options = {}) {
  const svg = await generateWaveformSVG(audioUrl, options)
  containerElement.innerHTML = svg
}

/**
 * Generate waveform canvas (alternative to SVG)
 * Better performance for many waveforms on one page
 */
export async function generateWaveformCanvas(audioUrl, canvas, options = {}) {
  const {
    barCount = 50,
    barGap = 2,
    barColor = '#d4af37',
    barMinHeight = 3,
    centerBars = true
  } = options

  const ctx = canvas.getContext('2d')
  const width = canvas.width
  const height = canvas.height

  // Clear canvas
  ctx.clearRect(0, 0, width, height)

  try {
    // Fetch and decode audio
    const audioContext = new (window.AudioContext || window.webkitAudioContext)()
    const response = await fetch(audioUrl)
    const arrayBuffer = await response.arrayBuffer()
    const audioBuffer = await audioContext.decodeAudioData(arrayBuffer)

    // Get audio data
    const rawData = audioBuffer.getChannelData(0)
    const samples = barCount
    const blockSize = Math.floor(rawData.length / samples)
    const filteredData = []

    // Get peak values
    for (let i = 0; i < samples; i++) {
      const blockStart = blockSize * i
      let sum = 0

      for (let j = 0; j < blockSize; j++) {
        const val = rawData[blockStart + j]
        sum += val * val
      }

      filteredData.push(Math.sqrt(sum / blockSize))
    }

    // Normalize
    const max = Math.max(...filteredData)
    const normalizedData = filteredData.map(n => n / max)

    // Draw bars
    const barWidth = (width - (barGap * (barCount - 1))) / barCount
    const barMaxHeight = height * 0.9

    ctx.fillStyle = barColor

    for (let i = 0; i < normalizedData.length; i++) {
      const barHeight = Math.max(
        barMinHeight,
        normalizedData[i] * barMaxHeight
      )

      const x = i * (barWidth + barGap)
      const y = centerBars ? (height - barHeight) / 2 : height - barHeight

      // Draw rounded rectangle
      const radius = 1
      ctx.beginPath()
      ctx.roundRect(x, y, barWidth, barHeight, radius)
      ctx.fill()
    }

  } catch (error) {
    console.error('Error generating canvas waveform:', error)

    // Draw placeholder
    ctx.fillStyle = barColor
    ctx.globalAlpha = 0.5

    const barWidth = (width - (barGap * (barCount - 1))) / barCount

    for (let i = 0; i < barCount; i++) {
      const barHeight = Math.random() * height * 0.7 + height * 0.1
      const x = i * (barWidth + barGap)
      const y = (height - barHeight) / 2

      ctx.beginPath()
      ctx.roundRect(x, y, barWidth, barHeight, 1)
      ctx.fill()
    }
  }
}

/**
 * Create animated waveform with playback progress
 * @param {string} audioUrl - URL of the audio file
 * @param {HTMLElement} container - Container element
 * @param {HTMLAudioElement} audioElement - The audio player element
 */
export async function createAnimatedWaveform(audioUrl, container, audioElement) {
  // Create two waveforms: background (gray) and progress (gold)
  const bgWaveform = document.createElement('div')
  bgWaveform.className = 'waveform-background'
  bgWaveform.style.cssText = 'position: absolute; top: 0; left: 0; width: 100%; height: 100%;'

  const progressWaveform = document.createElement('div')
  progressWaveform.className = 'waveform-progress'
  progressWaveform.style.cssText = 'position: absolute; top: 0; left: 0; width: 0%; height: 100%; overflow: hidden;'

  const progressInner = document.createElement('div')
  progressInner.style.cssText = 'width: 100vw; height: 100%;'
  progressWaveform.appendChild(progressInner)

  container.style.position = 'relative'
  container.appendChild(bgWaveform)
  container.appendChild(progressWaveform)

  // Generate waveforms
  await injectWaveform(audioUrl, bgWaveform, {
    width: container.offsetWidth,
    height: container.offsetHeight,
    barColor: 'rgba(255, 255, 255, 0.3)'
  })

  await injectWaveform(audioUrl, progressInner, {
    width: container.offsetWidth,
    height: container.offsetHeight,
    barColor: '#d4af37'
  })

  // Update progress
  audioElement.addEventListener('timeupdate', () => {
    const progress = (audioElement.currentTime / audioElement.duration) * 100
    progressWaveform.style.width = `${progress}%`
  })

  // Reset on ended
  audioElement.addEventListener('ended', () => {
    progressWaveform.style.width = '0%'
  })
}

/**
 * Batch generate waveforms for multiple voice notes
 * @param {Array} voiceNotes - Array of {id, audioUrl} objects
 * @param {Function} onProgress - Callback for progress updates
 * @returns {Promise<Map>} Map of id -> SVG string
 */
export async function batchGenerateWaveforms(voiceNotes, onProgress = null) {
  const waveforms = new Map()
  const total = voiceNotes.length

  for (let i = 0; i < voiceNotes.length; i++) {
    const note = voiceNotes[i]

    try {
      const svg = await generateWaveformSVG(note.audioUrl, {
        width: 300,
        height: 60
      })

      waveforms.set(note.id, svg)

      if (onProgress) {
        onProgress({
          completed: i + 1,
          total,
          percentage: ((i + 1) / total) * 100,
          currentId: note.id
        })
      }

    } catch (error) {
      console.error(`Error generating waveform for ${note.id}:`, error)
      // Store placeholder instead
      waveforms.set(note.id, generatePlaceholderWaveform(300, 60, '#d4af37'))
    }

    // Small delay to prevent UI blocking
    await new Promise(resolve => setTimeout(resolve, 10))
  }

  return waveforms
}

/**
 * Cache waveforms in localStorage
 */
export class WaveformCache {
  constructor(prefix = 'waveform_') {
    this.prefix = prefix
  }

  // Store waveform
  set(audioUrl, svg) {
    try {
      const key = this.prefix + this.hashUrl(audioUrl)
      localStorage.setItem(key, svg)
    } catch (error) {
      console.warn('Could not cache waveform:', error)
    }
  }

  // Retrieve waveform
  get(audioUrl) {
    try {
      const key = this.prefix + this.hashUrl(audioUrl)
      return localStorage.getItem(key)
    } catch (error) {
      console.warn('Could not retrieve cached waveform:', error)
      return null
    }
  }

  // Check if waveform is cached
  has(audioUrl) {
    const key = this.prefix + this.hashUrl(audioUrl)
    return localStorage.getItem(key) !== null
  }

  // Clear all waveform cache
  clear() {
    const keys = []
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      if (key.startsWith(this.prefix)) {
        keys.push(key)
      }
    }
    keys.forEach(key => localStorage.removeItem(key))
  }

  // Simple hash function for URLs
  hashUrl(url) {
    let hash = 0
    for (let i = 0; i < url.length; i++) {
      const char = url.charCodeAt(i)
      hash = ((hash << 5) - hash) + char
      hash = hash & hash // Convert to 32-bit integer
    }
    return Math.abs(hash).toString(36)
  }
}

// Export cache instance
export const waveformCache = new WaveformCache()

/**
 * Generate waveform with caching
 */
export async function generateWaveformWithCache(audioUrl, options = {}) {
  // Check cache first
  const cached = waveformCache.get(audioUrl)
  if (cached) {
    return cached
  }

  // Generate new
  const svg = await generateWaveformSVG(audioUrl, options)

  // Cache it
  waveformCache.set(audioUrl, svg)

  return svg
}

// Export for global access
window.waveformGenerator = {
  generateWaveformSVG,
  injectWaveform,
  generateWaveformCanvas,
  createAnimatedWaveform,
  batchGenerateWaveforms,
  generateWaveformWithCache,
  waveformCache,
  WaveformCache
}
