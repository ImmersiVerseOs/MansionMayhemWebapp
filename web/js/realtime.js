/**
 * MANSION MAYHEM - REAL-TIME MODULE
 * =================================
 * Handles all real-time subscriptions using Supabase Realtime
 *
 * Features:
 * - Real-time voting updates
 * - Live game status changes
 * - Notification system
 * - Live chat for cast members
 */

class RealtimeManager {
  constructor(supabaseClient) {
    this.supabase = supabaseClient;
    this.subscriptions = new Map();
    this.handlers = new Map();
  }

  // ============================================================
  // VOTING REAL-TIME UPDATES
  // ============================================================

  /**
   * Subscribe to real-time vote count updates for a game
   * @param {string} gameId - The game ID
   * @param {Function} callback - Called when vote counts update
   * @returns {string} subscription ID
   */
  subscribeToVotes(gameId, callback) {
    const channelName = `votes:${gameId}`;

    const channel = this.supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'vote_counts',
          filter: `game_id=eq.${gameId}`
        },
        (payload) => {
          console.log('📊 Vote update:', payload);
          callback(payload);
        }
      )
      .subscribe((status) => {
        console.log(`📊 Vote subscription status: ${status}`);
      });

    this.subscriptions.set(channelName, channel);
    return channelName;
  }

  /**
   * Fetch current vote counts for a game
   * @param {string} gameId - The game ID
   * @param {string} voteType - Type of vote ('elimination', 'hot_seat', etc.)
   */
  async getVoteCounts(gameId, voteType) {
    const { data, error } = await this.supabase
      .from('vote_counts')
      .select(`
        *,
        cast_member:cast_members(id, display_name, full_name)
      `)
      .eq('game_id', gameId)
      .eq('vote_type', voteType)
      .order('vote_count', { ascending: false });

    if (error) {
      console.error('❌ Error fetching vote counts:', error);
      return null;
    }

    return data;
  }

  // ============================================================
  // GAME STATUS REAL-TIME UPDATES
  // ============================================================

  /**
   * Subscribe to game status changes
   * @param {string} gameId - The game ID
   * @param {Function} callback - Called when game status changes
   * @returns {string} subscription ID
   */
  subscribeToGameStatus(gameId, callback) {
    const channelName = `game:${gameId}`;

    const channel = this.supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'mm_games',
          filter: `id=eq.${gameId}`
        },
        (payload) => {
          console.log('🎮 Game status update:', payload);
          callback(payload.new);
        }
      )
      .subscribe((status) => {
        console.log(`🎮 Game subscription status: ${status}`);
      });

    this.subscriptions.set(channelName, channel);
    return channelName;
  }

  /**
   * Subscribe to all active games (for admin dashboard)
   * @param {Function} callback - Called when any game changes
   * @returns {string} subscription ID
   */
  subscribeToAllGames(callback) {
    const channelName = 'all-games';

    const channel = this.supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'mm_games'
        },
        (payload) => {
          console.log('🎮 Game change:', payload);
          callback(payload);
        }
      )
      .subscribe((status) => {
        console.log(`🎮 All games subscription status: ${status}`);
      });

    this.subscriptions.set(channelName, channel);
    return channelName;
  }

  // ============================================================
  // NOTIFICATIONS REAL-TIME
  // ============================================================

  /**
   * Subscribe to notifications for current user
   * @param {Function} callback - Called when new notification arrives
   * @returns {string} subscription ID
   */
  subscribeToNotifications(callback) {
    const channelName = 'user-notifications';

    const channel = this.supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications'
        },
        (payload) => {
          console.log('🔔 New notification:', payload);
          callback(payload.new);

          // Show browser notification if permission granted
          this.showBrowserNotification(payload.new);
        }
      )
      .subscribe((status) => {
        console.log(`🔔 Notifications subscription status: ${status}`);
      });

    this.subscriptions.set(channelName, channel);
    return channelName;
  }

  /**
   * Get unread notifications count
   */
  async getUnreadCount() {
    const { count, error } = await this.supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('read', false);

    if (error) {
      console.error('❌ Error fetching unread count:', error);
      return 0;
    }

    return count;
  }

  /**
   * Get recent notifications
   * @param {number} limit - Number of notifications to fetch
   */
  async getNotifications(limit = 20) {
    const { data, error } = await this.supabase
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) {
      console.error('❌ Error fetching notifications:', error);
      return [];
    }

    return data;
  }

  /**
   * Mark notification as read
   * @param {string} notificationId - The notification ID
   */
  async markAsRead(notificationId) {
    const { error } = await this.supabase
      .from('notifications')
      .update({ read: true, read_at: new Date().toISOString() })
      .eq('id', notificationId);

    if (error) {
      console.error('❌ Error marking notification as read:', error);
    }
  }

  /**
   * Mark all notifications as read
   */
  async markAllAsRead() {
    const { error } = await this.supabase
      .from('notifications')
      .update({ read: true, read_at: new Date().toISOString() })
      .eq('read', false);

    if (error) {
      console.error('❌ Error marking all as read:', error);
    }
  }

  /**
   * Show browser notification
   */
  showBrowserNotification(notification) {
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(notification.title, {
        body: notification.message,
        icon: '/mansion-mayhem/favicon.ico',
        badge: '/mansion-mayhem/favicon.ico',
        tag: notification.id
      });
    }
  }

  /**
   * Request notification permission
   */
  async requestNotificationPermission() {
    if ('Notification' in window && Notification.permission === 'default') {
      const permission = await Notification.requestPermission();
      return permission === 'granted';
    }
    return Notification.permission === 'granted';
  }

  // ============================================================
  // CHAT REAL-TIME
  // ============================================================

  /**
   * Subscribe to chat messages for a game
   * @param {string} gameId - The game ID
   * @param {Function} callback - Called when new message arrives
   * @returns {string} subscription ID
   */
  subscribeToChat(gameId, callback) {
    const channelName = `chat:${gameId}`;

    const channel = this.supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'chat_messages',
          filter: `game_id=eq.${gameId}`
        },
        (payload) => {
          console.log('💬 Chat update:', payload);

          // Handle different events
          if (payload.eventType === 'INSERT') {
            callback({ type: 'new', message: payload.new });
          } else if (payload.eventType === 'UPDATE') {
            callback({ type: 'update', message: payload.new });
          } else if (payload.eventType === 'DELETE') {
            callback({ type: 'delete', messageId: payload.old.id });
          }
        }
      )
      .subscribe((status) => {
        console.log(`💬 Chat subscription status: ${status}`);
      });

    this.subscriptions.set(channelName, channel);
    return channelName;
  }

  /**
   * Send a chat message
   * @param {string} gameId - The game ID
   * @param {string} castMemberId - The sender's cast member ID
   * @param {string} message - The message text
   * @param {object} options - Additional options (replyTo, mentions, metadata)
   */
  async sendMessage(gameId, castMemberId, message, options = {}) {
    const { data, error } = await this.supabase
      .from('chat_messages')
      .insert({
        game_id: gameId,
        sender_cast_member_id: castMemberId,
        message: message,
        reply_to: options.replyTo || null,
        mentions: options.mentions || [],
        metadata: options.metadata || {}
      })
      .select(`
        *,
        cast_member:cast_members(id, display_name, full_name)
      `)
      .maybeSingle();

    if (error) {
      console.error('❌ Error sending message:', error);
      return null;
    }

    return data;
  }

  /**
   * Get chat history for a game
   * @param {string} gameId - The game ID
   * @param {number} limit - Number of messages to fetch
   */
  async getChatHistory(gameId, limit = 50) {
    const { data, error } = await this.supabase
      .from('chat_messages')
      .select(`
        *,
        cast_member:cast_members(id, display_name, full_name),
        reply_to_message:chat_messages!reply_to(id, message, cast_member_id)
      `)
      .eq('game_id', gameId)
      .eq('deleted', false)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) {
      console.error('❌ Error fetching chat history:', error);
      return [];
    }

    return data.reverse(); // Return oldest first
  }

  /**
   * Edit a message
   * @param {string} messageId - The message ID
   * @param {string} newMessage - The new message text
   */
  async editMessage(messageId, newMessage) {
    const { error } = await this.supabase
      .from('chat_messages')
      .update({
        message: newMessage,
        edited: true,
        edited_at: new Date().toISOString()
      })
      .eq('id', messageId);

    if (error) {
      console.error('❌ Error editing message:', error);
      return false;
    }

    return true;
  }

  /**
   * Delete a message
   * @param {string} messageId - The message ID
   */
  async deleteMessage(messageId) {
    const { error } = await this.supabase
      .from('chat_messages')
      .update({
        deleted: true,
        deleted_at: new Date().toISOString()
      })
      .eq('id', messageId);

    if (error) {
      console.error('❌ Error deleting message:', error);
      return false;
    }

    return true;
  }

  // ============================================================
  // SCENARIO NOTIFICATIONS
  // ============================================================

  /**
   * Subscribe to new scenarios for current cast member
   * @param {Function} callback - Called when new scenario is assigned
   * @returns {string} subscription ID
   */
  subscribeToScenarios(callback) {
    const channelName = 'scenarios';

    const channel = this.supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'scenarios'
        },
        (payload) => {
          console.log('🎬 New scenario:', payload);
          callback(payload.new);
        }
      )
      .subscribe((status) => {
        console.log(`🎬 Scenarios subscription status: ${status}`);
      });

    this.subscriptions.set(channelName, channel);
    return channelName;
  }

  // ============================================================
  // PRESENCE (Who's Online)
  // ============================================================

  /**
   * Subscribe to presence for a game (see who's online)
   * @param {string} gameId - The game ID
   * @param {string} castMemberId - Current cast member ID
   * @param {Function} callback - Called when presence changes
   * @returns {string} subscription ID
   */
  subscribeToPresence(gameId, castMemberId, castMemberName, callback) {
    const channelName = `presence:${gameId}`;

    const channel = this.supabase
      .channel(channelName)
      .on('presence', { event: 'sync' }, () => {
        const state = channel.presenceState();
        console.log('👥 Presence sync:', state);
        callback({ type: 'sync', state });
      })
      .on('presence', { event: 'join' }, ({ key, newPresences }) => {
        console.log('👤 User joined:', newPresences);
        callback({ type: 'join', presences: newPresences });
      })
      .on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
        console.log('👤 User left:', leftPresences);
        callback({ type: 'leave', presences: leftPresences });
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          // Track this user's presence
          await channel.track({
            sender_cast_member_id: castMemberId,
            cast_member_name: castMemberName,
            online_at: new Date().toISOString()
          });
        }
      });

    this.subscriptions.set(channelName, channel);
    return channelName;
  }

  // ============================================================
  // SUBSCRIPTION MANAGEMENT
  // ============================================================

  /**
   * Unsubscribe from a specific channel
   * @param {string} channelName - The channel name/ID
   */
  async unsubscribe(channelName) {
    const channel = this.subscriptions.get(channelName);
    if (channel) {
      await this.supabase.removeChannel(channel);
      this.subscriptions.delete(channelName);
      console.log(`📡 Unsubscribed from: ${channelName}`);
    }
  }

  /**
   * Unsubscribe from all channels
   */
  async unsubscribeAll() {
    for (const [name, channel] of this.subscriptions) {
      await this.supabase.removeChannel(channel);
      console.log(`📡 Unsubscribed from: ${name}`);
    }
    this.subscriptions.clear();
  }

  /**
   * Get active subscriptions
   */
  getActiveSubscriptions() {
    return Array.from(this.subscriptions.keys());
  }
}

// Export for use in other files
window.RealtimeManager = RealtimeManager;

console.log('✅ Realtime module loaded');
