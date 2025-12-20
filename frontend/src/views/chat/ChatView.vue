<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted, nextTick, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useContactsStore, type Contact, type Message } from '@/stores/contacts'
import { wsService } from '@/services/websocket'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Separator } from '@/components/ui/separator'
import { Skeleton } from '@/components/ui/skeleton'
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from '@/components/ui/tooltip'
import { toast } from 'vue-sonner'
import {
  Search,
  Send,
  Paperclip,
  Image,
  FileText,
  Smile,
  MoreVertical,
  Phone,
  Video,
  Check,
  CheckCheck,
  Clock,
  AlertCircle,
  User
} from 'lucide-vue-next'
import { formatTime, getInitials, truncate } from '@/lib/utils'

const route = useRoute()
const router = useRouter()
const contactsStore = useContactsStore()

const messageInput = ref('')
const messagesEndRef = ref<HTMLElement | null>(null)
const isSending = ref(false)

const contactId = computed(() => route.params.contactId as string | undefined)

// Initialize WebSocket connection
function initWebSocket() {
  const token = localStorage.getItem('auth_token')
  if (token) {
    wsService.connect(token)
  }
}

// Fetch contacts on mount and connect WebSocket
onMounted(async () => {
  await contactsStore.fetchContacts()
  initWebSocket()

  if (contactId.value) {
    await selectContact(contactId.value)
  }
})

onUnmounted(() => {
  wsService.setCurrentContact(null)
})

// Watch for route changes
watch(contactId, async (newId) => {
  if (newId) {
    await selectContact(newId)
  } else {
    wsService.setCurrentContact(null)
    contactsStore.setCurrentContact(null)
    contactsStore.clearMessages()
  }
})

async function selectContact(id: string) {
  const contact = contactsStore.contacts.find(c => c.id === id)
  if (contact) {
    contactsStore.setCurrentContact(contact)
    await contactsStore.fetchMessages(id)
    scrollToBottom()
    // Tell WebSocket server which contact we're viewing
    wsService.setCurrentContact(id)
  }
}

// Watch for new messages to auto-scroll
watch(() => contactsStore.messages.length, () => {
  scrollToBottom()
})

function handleContactClick(contact: Contact) {
  router.push(`/chat/${contact.id}`)
}

async function sendMessage() {
  if (!messageInput.value.trim() || !contactsStore.currentContact) return

  isSending.value = true
  try {
    await contactsStore.sendMessage(
      contactsStore.currentContact.id,
      'text',
      { body: messageInput.value }
    )
    messageInput.value = ''
    await nextTick()
    scrollToBottom()
  } catch (error) {
    toast.error('Failed to send message')
  } finally {
    isSending.value = false
  }
}

function scrollToBottom() {
  nextTick(() => {
    if (messagesEndRef.value) {
      messagesEndRef.value.scrollIntoView({ behavior: 'smooth' })
    }
  })
}

function getMessageStatusIcon(status: string) {
  switch (status) {
    case 'sent':
      return Check
    case 'delivered':
      return CheckCheck
    case 'read':
      return CheckCheck
    case 'failed':
      return AlertCircle
    default:
      return Clock
  }
}

function getMessageStatusClass(status: string) {
  switch (status) {
    case 'read':
      return 'text-blue-500'
    case 'failed':
      return 'text-destructive'
    default:
      return 'text-muted-foreground'
  }
}

function formatMessageTime(dateStr: string) {
  const date = new Date(dateStr)
  return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
}

function formatContactTime(dateStr?: string) {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  const now = new Date()
  const diffDays = Math.floor((now.getTime() - date.getTime()) / 86400000)

  if (diffDays === 0) {
    return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
  } else if (diffDays === 1) {
    return 'Yesterday'
  } else if (diffDays < 7) {
    return date.toLocaleDateString('en-US', { weekday: 'short' })
  }
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

function getMessageContent(message: Message): string {
  if (message.message_type === 'text') {
    return message.content?.body || ''
  }
  if (message.message_type === 'image') {
    return '[Image]'
  }
  if (message.message_type === 'document') {
    return '[Document]'
  }
  if (message.message_type === 'template') {
    return '[Template Message]'
  }
  return '[Message]'
}
</script>

<template>
  <div class="flex h-full">
    <!-- Contacts List -->
    <div class="w-80 border-r flex flex-col bg-card">
      <!-- Search Header -->
      <div class="p-4 border-b">
        <div class="relative">
          <Search class="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            v-model="contactsStore.searchQuery"
            placeholder="Search contacts..."
            class="pl-9"
          />
        </div>
      </div>

      <!-- Contacts -->
      <ScrollArea class="flex-1">
        <div class="py-2">
          <div
            v-for="contact in contactsStore.sortedContacts"
            :key="contact.id"
            :class="[
              'flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-accent transition-colors',
              contactsStore.currentContact?.id === contact.id && 'bg-accent'
            ]"
            @click="handleContactClick(contact)"
          >
            <Avatar class="h-12 w-12">
              <AvatarImage :src="contact.avatar_url" />
              <AvatarFallback>
                {{ getInitials(contact.name || contact.phone_number) }}
              </AvatarFallback>
            </Avatar>
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between">
                <p class="font-medium truncate">
                  {{ contact.name || contact.phone_number }}
                </p>
                <span class="text-xs text-muted-foreground">
                  {{ formatContactTime(contact.last_message_at) }}
                </span>
              </div>
              <div class="flex items-center justify-between mt-0.5">
                <p class="text-sm text-muted-foreground truncate">
                  {{ contact.profile_name || contact.phone_number }}
                </p>
                <Badge v-if="contact.unread_count > 0" class="ml-2">
                  {{ contact.unread_count }}
                </Badge>
              </div>
            </div>
          </div>

          <div v-if="contactsStore.sortedContacts.length === 0" class="p-4 text-center text-muted-foreground">
            <User class="h-8 w-8 mx-auto mb-2 opacity-50" />
            <p>No contacts found</p>
          </div>
        </div>
      </ScrollArea>
    </div>

    <!-- Chat Area -->
    <div class="flex-1 flex flex-col">
      <!-- No Contact Selected -->
      <div
        v-if="!contactsStore.currentContact"
        class="flex-1 flex items-center justify-center text-muted-foreground"
      >
        <div class="text-center">
          <div class="h-16 w-16 rounded-full bg-muted flex items-center justify-center mx-auto mb-4">
            <Send class="h-8 w-8" />
          </div>
          <h3 class="font-medium text-lg mb-1">Select a conversation</h3>
          <p class="text-sm">Choose a contact to start chatting</p>
        </div>
      </div>

      <!-- Chat Interface -->
      <template v-else>
        <!-- Chat Header -->
        <div class="h-16 px-4 border-b flex items-center justify-between bg-card">
          <div class="flex items-center gap-3">
            <Avatar class="h-10 w-10">
              <AvatarImage :src="contactsStore.currentContact.avatar_url" />
              <AvatarFallback>
                {{ getInitials(contactsStore.currentContact.name || contactsStore.currentContact.phone_number) }}
              </AvatarFallback>
            </Avatar>
            <div>
              <p class="font-medium">
                {{ contactsStore.currentContact.name || contactsStore.currentContact.phone_number }}
              </p>
              <p class="text-xs text-muted-foreground">
                {{ contactsStore.currentContact.phone_number }}
              </p>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <Tooltip>
              <TooltipTrigger as-child>
                <Button variant="ghost" size="icon">
                  <Phone class="h-5 w-5" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Voice call</TooltipContent>
            </Tooltip>
            <Tooltip>
              <TooltipTrigger as-child>
                <Button variant="ghost" size="icon">
                  <Video class="h-5 w-5" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Video call</TooltipContent>
            </Tooltip>
            <Tooltip>
              <TooltipTrigger as-child>
                <Button variant="ghost" size="icon">
                  <MoreVertical class="h-5 w-5" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>More options</TooltipContent>
            </Tooltip>
          </div>
        </div>

        <!-- Messages -->
        <ScrollArea class="flex-1 p-4">
          <div class="space-y-4">
            <div
              v-for="message in contactsStore.messages"
              :key="message.id"
              :class="[
                'flex',
                message.direction === 'outgoing' ? 'justify-end' : 'justify-start'
              ]"
            >
              <div
                :class="[
                  'chat-bubble',
                  message.direction === 'outgoing' ? 'chat-bubble-outgoing' : 'chat-bubble-incoming'
                ]"
              >
                <p class="whitespace-pre-wrap break-words">{{ getMessageContent(message) }}</p>
                <div
                  :class="[
                    'chat-bubble-time flex items-center gap-1',
                    message.direction === 'outgoing' ? 'justify-end' : 'justify-start'
                  ]"
                >
                  <span>{{ formatMessageTime(message.created_at) }}</span>
                  <component
                    v-if="message.direction === 'outgoing'"
                    :is="getMessageStatusIcon(message.status)"
                    :class="['h-3 w-3', getMessageStatusClass(message.status)]"
                  />
                </div>
              </div>
            </div>
            <div ref="messagesEndRef" />
          </div>
        </ScrollArea>

        <!-- Message Input -->
        <div class="p-4 border-t bg-card">
          <form @submit.prevent="sendMessage" class="flex items-end gap-2">
            <div class="flex gap-1">
              <Tooltip>
                <TooltipTrigger as-child>
                  <Button type="button" variant="ghost" size="icon">
                    <Smile class="h-5 w-5" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Emoji</TooltipContent>
              </Tooltip>
              <Tooltip>
                <TooltipTrigger as-child>
                  <Button type="button" variant="ghost" size="icon">
                    <Paperclip class="h-5 w-5" />
                  </Button>
                </TooltipTrigger>
                <TooltipContent>Attach file</TooltipContent>
              </Tooltip>
            </div>
            <Textarea
              v-model="messageInput"
              placeholder="Type a message..."
              class="flex-1 min-h-[40px] max-h-[120px] resize-none"
              :rows="1"
              @keydown.enter.exact.prevent="sendMessage"
            />
            <Tooltip>
              <TooltipTrigger as-child>
                <Button
                  type="submit"
                  size="icon"
                  :disabled="!messageInput.trim() || isSending"
                >
                  <Send class="h-5 w-5" />
                </Button>
              </TooltipTrigger>
              <TooltipContent>Send message</TooltipContent>
            </Tooltip>
          </form>
        </div>
      </template>
    </div>
  </div>
</template>
