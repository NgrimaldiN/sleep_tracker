import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icon.png'],
      manifest: {
        name: 'Sleep Tracker',
        short_name: 'Sleep',
        description: 'Track your sleep and habits',
        theme_color: '#18181b',
        background_color: '#18181b',
        display: 'standalone',
        icons: [
          {
            src: 'icon.png',
            sizes: '1024x1024',
            type: 'image/png'
          }
        ]
      }
    })
  ],
})
