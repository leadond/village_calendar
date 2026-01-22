import { nylasConfig } from '../nylas.config';

interface NylasEvent {
  id: string;
  title: string;
  description?: string;
  when: {
    start_time?: number;
    start_date?: string;
  };
  participants?: Array<{
    email: string;
    name?: string;
  }>;
  location?: string;
  calendar_id?: string;
}

export interface CalendarEvent {
  id: string;
  title: string;
  description?: string;
  date: string;
  startTime?: string;
  type: 'work_schedule' | 'help_request';
  status: 'OPEN' | 'CLAIMED';
}

export const nylasService = {
  // Fetch calendar events from Nylas API
  async getCalendarEvents(): Promise<CalendarEvent[]> {
    try {
      // Using your API key for authentication
      const response = await fetch(
        'https://api.nylas.com/v3/calendars/primary/events',
        {
          method: 'GET',
          headers: {
            Authorization: `Bearer ${nylasConfig.apiKey}`,
            'Content-Type': 'application/json',
          },
        }
      );

      if (!response.ok) {
        throw new Error(`Nylas API error: ${response.status}`);
      }

      const data = await response.json();
      const nylasEvents = data.data || [];

      // Transform Nylas events to our format
      return nylasEvents.map((event: NylasEvent) => {
        // Determine if this is a help request based on event title or description
        const isHelpRequest = 
          event.title?.toLowerCase().includes('help') ||
          event.description?.toLowerCase().includes('help request');

        // Get date and time
        const startTime = event.when?.start_time ? 
          new Date(event.when.start_time * 1000).toISOString().split('T')[1].substring(0, 5) :
          '09:00';
        
        const date = event.when?.start_date || 
          (event.when?.start_time ? new Date(event.when.start_time * 1000).toISOString().split('T')[0] : '');

        return {
          id: event.id,
          title: event.title || 'Untitled Event',
          description: event.description,
          date,
          startTime,
          type: isHelpRequest ? 'help_request' : 'work_schedule',
          status: 'OPEN' as const,
        };
      });
    } catch (error) {
      console.error('Error fetching Nylas events:', error);
      return [];
    }
  },

  // Create a new calendar event (for help requests posted by parents)
  async createEvent(
    title: string,
    description: string,
    startTime: number,
    endTime?: number
  ): Promise<NylasEvent | null> {
    try {
      const response = await fetch(
        'https://api.nylas.com/v3/calendars/primary/events',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${nylasConfig.apiKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            title,
            description,
            when: {
              start_time: Math.floor(startTime / 1000),
              end_time: endTime ? Math.floor(endTime / 1000) : undefined,
            },
          }),
        }
      );

      if (!response.ok) {
        throw new Error(`Failed to create event: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Error creating Nylas event:', error);
      return null;
    }
  },
};