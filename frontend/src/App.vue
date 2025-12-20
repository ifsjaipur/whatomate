<script setup lang="ts">
import { RouterView } from 'vue-router'
import { Toaster } from 'vue-sonner'
import { TooltipProvider } from '@/components/ui/tooltip'
</script>

<template>
  <TooltipProvider>
    <div class="min-h-screen bg-background">
      <RouterView />
      <Toaster position="top-right" richColors />
    </div>
  </TooltipProvider>
</template>
