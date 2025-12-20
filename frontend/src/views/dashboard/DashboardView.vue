<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Skeleton } from '@/components/ui/skeleton'
import { analyticsService } from '@/services/api'
import {
  MessageSquare,
  Users,
  Bot,
  Send,
  TrendingUp,
  TrendingDown,
  Clock,
  CheckCheck
} from 'lucide-vue-next'

interface DashboardStats {
  total_messages: number
  messages_change: number
  total_contacts: number
  contacts_change: number
  chatbot_sessions: number
  chatbot_change: number
  campaigns_sent: number
  campaigns_change: number
}

interface RecentMessage {
  id: string
  contact_name: string
  content: string
  direction: string
  created_at: string
  status: string
}

const stats = ref<DashboardStats>({
  total_messages: 0,
  messages_change: 0,
  total_contacts: 0,
  contacts_change: 0,
  chatbot_sessions: 0,
  chatbot_change: 0,
  campaigns_sent: 0,
  campaigns_change: 0
})

const recentMessages = ref<RecentMessage[]>([])
const isLoading = ref(true)

const statCards = [
  {
    title: 'Total Messages',
    key: 'total_messages',
    changeKey: 'messages_change',
    icon: MessageSquare,
    color: 'text-blue-500'
  },
  {
    title: 'Contacts',
    key: 'total_contacts',
    changeKey: 'contacts_change',
    icon: Users,
    color: 'text-green-500'
  },
  {
    title: 'Chatbot Sessions',
    key: 'chatbot_sessions',
    changeKey: 'chatbot_change',
    icon: Bot,
    color: 'text-purple-500'
  },
  {
    title: 'Campaigns Sent',
    key: 'campaigns_sent',
    changeKey: 'campaigns_change',
    icon: Send,
    color: 'text-orange-500'
  }
]

const formatNumber = (num: number): string => {
  if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M'
  if (num >= 1000) return (num / 1000).toFixed(1) + 'K'
  return num.toString()
}

const formatTime = (dateStr: string): string => {
  const date = new Date(dateStr)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)

  if (diffMins < 1) return 'Just now'
  if (diffMins < 60) return `${diffMins}m ago`
  if (diffHours < 24) return `${diffHours}h ago`
  return `${diffDays}d ago`
}

onMounted(async () => {
  try {
    const response = await analyticsService.dashboard()
    // API response is wrapped in { status: "success", data: { stats: {...}, recent_messages: [...] } }
    const data = response.data.data || response.data
    stats.value = data.stats || {
      total_messages: 0,
      messages_change: 0,
      total_contacts: 0,
      contacts_change: 0,
      chatbot_sessions: 0,
      chatbot_change: 0,
      campaigns_sent: 0,
      campaigns_change: 0
    }
    recentMessages.value = data.recent_messages || []
  } catch (error) {
    console.error('Failed to load dashboard data:', error)
    // Use empty data on error
    stats.value = {
      total_messages: 0,
      messages_change: 0,
      total_contacts: 0,
      contacts_change: 0,
      chatbot_sessions: 0,
      chatbot_change: 0,
      campaigns_sent: 0,
      campaigns_change: 0
    }
    recentMessages.value = []
  } finally {
    isLoading.value = false
  }
})
</script>

<template>
  <div class="flex flex-col h-full">
    <!-- Header -->
    <header class="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div class="flex h-16 items-center px-6">
        <h1 class="text-xl font-semibold">Dashboard</h1>
      </div>
    </header>

    <!-- Content -->
    <ScrollArea class="flex-1">
      <div class="p-6 space-y-6">
        <!-- Stats Cards -->
        <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <!-- Skeleton Loading State -->
          <template v-if="isLoading">
            <Card v-for="i in 4" :key="i">
              <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
                <Skeleton class="h-4 w-24" />
                <Skeleton class="h-5 w-5 rounded" />
              </CardHeader>
              <CardContent>
                <Skeleton class="h-8 w-20 mb-2" />
                <Skeleton class="h-3 w-32" />
              </CardContent>
            </Card>
          </template>
          <!-- Actual Stats -->
          <template v-else>
            <Card v-for="card in statCards" :key="card.key">
              <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle class="text-sm font-medium">
                  {{ card.title }}
                </CardTitle>
                <component :is="card.icon" :class="['h-5 w-5', card.color]" />
              </CardHeader>
              <CardContent>
                <div class="text-2xl font-bold">
                  {{ formatNumber(stats[card.key as keyof DashboardStats] as number) }}
                </div>
                <div class="flex items-center text-xs text-muted-foreground mt-1">
                  <component
                    :is="(stats[card.changeKey as keyof DashboardStats] as number) >= 0 ? TrendingUp : TrendingDown"
                    :class="[
                      'h-3 w-3 mr-1',
                      (stats[card.changeKey as keyof DashboardStats] as number) >= 0 ? 'text-green-500' : 'text-red-500'
                    ]"
                  />
                  <span :class="(stats[card.changeKey as keyof DashboardStats] as number) >= 0 ? 'text-green-500' : 'text-red-500'">
                    {{ Math.abs(stats[card.changeKey as keyof DashboardStats] as number).toFixed(1) }}%
                  </span>
                  <span class="ml-1">from last month</span>
                </div>
              </CardContent>
            </Card>
          </template>
        </div>

        <!-- Recent Activity -->
        <div class="grid gap-4 md:grid-cols-2">
          <!-- Recent Messages -->
          <Card>
            <CardHeader>
              <CardTitle>Recent Messages</CardTitle>
              <CardDescription>Latest conversations from your contacts</CardDescription>
            </CardHeader>
            <CardContent>
              <div class="space-y-4">
                <div
                  v-for="message in recentMessages"
                  :key="message.id"
                  class="flex items-start gap-3"
                >
                  <div
                    :class="[
                      'h-10 w-10 rounded-full flex items-center justify-center text-sm font-medium',
                      message.direction === 'incoming' ? 'bg-primary/10 text-primary' : 'bg-muted text-muted-foreground'
                    ]"
                  >
                    {{ message.contact_name.split(' ').map(n => n[0]).join('').slice(0, 2) }}
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center justify-between">
                      <p class="text-sm font-medium truncate">{{ message.contact_name }}</p>
                      <span class="text-xs text-muted-foreground flex items-center gap-1">
                        <Clock class="h-3 w-3" />
                        {{ formatTime(message.created_at) }}
                      </span>
                    </div>
                    <p class="text-sm text-muted-foreground truncate">{{ message.content }}</p>
                    <div class="flex items-center gap-2 mt-1">
                      <Badge :variant="message.direction === 'incoming' ? 'secondary' : 'default'" class="text-xs">
                        {{ message.direction }}
                      </Badge>
                      <span v-if="message.status === 'delivered'" class="text-xs text-muted-foreground flex items-center">
                        <CheckCheck class="h-3 w-3 mr-1" />
                        Delivered
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          <!-- Quick Actions -->
          <Card>
            <CardHeader>
              <CardTitle>Quick Actions</CardTitle>
              <CardDescription>Common tasks and shortcuts</CardDescription>
            </CardHeader>
            <CardContent>
              <div class="grid grid-cols-2 gap-3">
                <RouterLink
                  to="/chat"
                  class="flex flex-col items-center justify-center p-4 rounded-lg border hover:bg-accent transition-colors"
                >
                  <MessageSquare class="h-8 w-8 text-primary mb-2" />
                  <span class="text-sm font-medium">Start Chat</span>
                </RouterLink>
                <RouterLink
                  to="/campaigns"
                  class="flex flex-col items-center justify-center p-4 rounded-lg border hover:bg-accent transition-colors"
                >
                  <Send class="h-8 w-8 text-orange-500 mb-2" />
                  <span class="text-sm font-medium">New Campaign</span>
                </RouterLink>
                <RouterLink
                  to="/templates"
                  class="flex flex-col items-center justify-center p-4 rounded-lg border hover:bg-accent transition-colors"
                >
                  <span class="h-8 w-8 text-blue-500 mb-2 text-2xl">T</span>
                  <span class="text-sm font-medium">Templates</span>
                </RouterLink>
                <RouterLink
                  to="/chatbot"
                  class="flex flex-col items-center justify-center p-4 rounded-lg border hover:bg-accent transition-colors"
                >
                  <Bot class="h-8 w-8 text-purple-500 mb-2" />
                  <span class="text-sm font-medium">Chatbot</span>
                </RouterLink>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </ScrollArea>
  </div>
</template>
