import { NavigatorScreenParams } from '@react-navigation/native';
import { Id } from './convex/_generated/dataModel';

export type RootTabParamList = {
    Home: undefined;
    Calendar: undefined;
    MyItems: undefined;
    Profile: undefined;
};

export type RootStackParamList = {
    Loading: undefined;
    Onboarding: undefined;
    AuthStack: undefined;
    Login: undefined;
    Signup: undefined;
    MainTabs: NavigatorScreenParams<RootTabParamList>;
    CreateRequest: undefined;
    CreateEvent: undefined;
    Admin: undefined;
    Chat: {
        requestId: Id<"helpRequests">;
        requestTitle: string;
        requestDate: string;
        requestTime: string;
        requestDescription: string;
        isHelper: boolean;
    };
};

export interface Profile {
    _id: Id<"profiles">;
    _creationTime: number;
    userId: string; // legacy or subject
    name: string;
    email?: string;
    role: 'parent' | 'helper';
    villageId: Id<"villages">;
    tokenIdentifier?: string;
    issuer?: string;
    subject?: string;
}

export interface VillageEvent {
    _id: Id<"villageEvents">;
    title: string;
    description: string;
    date: string;
    time: string;
    createdByName: string;
    createdByPhotoUrl?: string;
}

export interface HelpRequest {
    _id: Id<"helpRequests">;
    title: string;
    description: string;
    date: string;
    time: string;
    status: 'open' | 'claimed';
    createdByName: string;
    createdByPhotoUrl?: string;
    claimedByName?: string;
    claimedByPhotoUrl?: string;
    isOwner: boolean;
}

export interface Message {
    id: Id<"messages">; // Return from query is mapped to 'id'
    senderId: string;
    senderName: string;
    senderPhotoUrl?: string;
    text: string;
    createdAt: number;
    isMe: boolean;
}
