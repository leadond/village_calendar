import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TouchableOpacity,
  RefreshControl,
  Alert,
  ActivityIndicator,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery } from 'convex/react';
import { api } from '../convex/_generated/api';
import { useNavigation } from '@react-navigation/native';
import { showSuccess } from '../utils/notifications';
import { triggerSuccessHaptic } from '../utils/haptics';
import { trackRequestClaimed } from '../utils/analytics';

import { theme } from '../lib/theme';
import { Ionicons } from '@expo/vector-icons';
import Skeleton from '../components/Skeleton';
import Avatar from '../components/Avatar';
interface Props {
  profile: {
    id: string;
    name: string;
    role: 'parent' | 'helper';
    villageId: any;
    villageName: string;
  };
}

const RequestSkeleton = () => (
  <View style={styles.card}>
    <View style={styles.cardRow}>
      <Skeleton width={48} height={48} style={{ borderRadius: 24 }} />
      <View style={{ flex: 1, marginLeft: 12, gap: 6 }}>
        <Skeleton width="70%" height={20} />
        <Skeleton width="40%" height={16} />
        <Skeleton width="30%" height={14} />
      </View>
      <Skeleton width={36} height={36} style={{ borderRadius: 18 }} />
    </View>
    <Skeleton width="100%" height={40} style={{ marginTop: 16, borderRadius: 12 }} />
  </View>
);

export default function HomeScreen({ profile }: Props) {
  const navigation = useNavigation<any>();

  const requests = useQuery(api.helpRequests.getVillageRequests, { villageId: profile.villageId });
  const [isClaiming, setIsClaiming] = React.useState<string | null>(null);

  const claimRequest = useMutation(api.helpRequests.claimRequest);

  const handleClaim = async (requestId: any) => {
    if (isClaiming) return;
    setIsClaiming(requestId);
    try {
      await claimRequest({ requestId });
      trackRequestClaimed({ villageId: profile.villageId, requestId });
      triggerSuccessHaptic();
      showSuccess("You're helping out!");
    } catch (error: any) {
      Alert.alert('Error', error?.message || 'Failed to claim request');
    } finally {
      setIsClaiming(null);
    }
  };

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    const today = new Date();
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    if (date.toDateString() === today.toDateString()) {
      return 'Today';
    } else if (date.toDateString() === tomorrow.toDateString()) {
      return 'Tomorrow';
    } else {
      return date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
    }
  };

  const renderRequest = ({ item }: { item: any }) => {
    const isOpen = item.status === 'open';
    const canClaim = profile.role === 'helper' && isOpen;
    const canChat = !isOpen && (item.isOwner || item.claimedByName);

    const openChat = () => {
      navigation.navigate('Chat', {
        requestId: item.id,
        requestTitle: item.title,
        requestDate: item.date,
        requestTime: item.time,
        requestDescription: item.description,
        isHelper: !item.isOwner,
      });
    };

    const isToday = new Date(item.date).toDateString() === new Date().toDateString();

    return (
      <View style={[styles.card, !isOpen && styles.cardClaimed]}>
        <View style={styles.cardRow}>
          {/* Left: Category Icon */}
          <View style={[styles.categoryIcon, isOpen ? styles.categoryOpen : styles.categoryClaimed]}>
            <Ionicons
              name={item.title.toLowerCase().includes('pick') ? 'car-sport' : 'home'}
              size={24}
              color={isOpen ? theme.colors.primary : theme.colors.status.claimed}
            />
          </View>

          {/* Middle: Content */}
          <View style={styles.cardContent}>
            <Text style={styles.cardTitle} numberOfLines={1}>{item.title}</Text>
            <Text style={styles.dateTime}>
              {formatDate(item.date)} • {item.time}
            </Text>
            <View style={styles.userRow}>
              <Text style={styles.postedBy}>by {item.createdByName}</Text>
            </View>
          </View>

          {/* Right: Avatar & Action */}
          <View style={styles.cardRight}>
            <Avatar name={item.createdByName} uri={item.createdByPhotoUrl} size={36} />
            {canChat && (
              <TouchableOpacity onPress={openChat} style={styles.miniChatBtn}>
                <Ionicons name="chatbubble" size={16} color={theme.colors.primary} />
              </TouchableOpacity>
            )}
          </View>
        </View>

        {/* Footer Actions */}
        {canClaim && (
          <TouchableOpacity
            style={styles.claimButton}
            onPress={() => handleClaim(item.id)}
            disabled={isClaiming === item.id}
          >
            {isClaiming === item.id ? (
              <ActivityIndicator color={theme.colors.white} />
            ) : (
              <Text style={styles.claimButtonText}>I'll Help</Text>
            )}
          </TouchableOpacity>
        )}
      </View>
    );
  };

  const openRequests = requests?.filter((r: any) => r.status === 'open') || [];
  const claimedRequests = requests?.filter((r: any) => r.status === 'claimed') || [];

  if (requests === undefined) {
    return (
      <SafeAreaView style={styles.container} edges={['top']}>
        <View style={styles.header}>
          <View>
            <Text style={styles.greeting}>Hello, {profile.name}!</Text>
            <Text style={styles.villageName}>{profile.villageName}</Text>
          </View>
          <View style={styles.roleBadge}>
            <Ionicons
              name={profile.role === 'parent' ? 'home' : 'heart'}
              size={14}
              color={theme.colors.primary}
            />
            <Text style={styles.roleText}>{profile.role === 'parent' ? 'Parent' : 'Helper'}</Text>
          </View>
        </View>
        <FlatList
          data={[1, 2, 3]}
          renderItem={() => <RequestSkeleton />}
          keyExtractor={(item) => `skeleton-${item}`}
          contentContainerStyle={styles.listContent}
          getItemLayout={(data, index) => ({
            length: 230,
            offset: 230 * index,
            index,
          })}
          removeClippedSubviews={true}
          maxToRenderPerBatch={5}
          windowSize={10}
          initialNumToRender={3}
          legacyImplementation={false}
        />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <View style={styles.headerTop}>
          <Image
            source={require('../assets/logo.png')}
            style={{ width: 40, height: 40, marginRight: 12 }}
            resizeMode="contain"
          />
          <View>
            <Text style={styles.greeting}>Hello, {profile.name}!</Text>
            <Text style={styles.villageName}>{profile.villageName}</Text>
          </View>
        </View>
        <View style={styles.roleBadge}>
          <Ionicons
            name={profile.role === 'parent' ? 'home' : 'heart'}
            size={14}
            color={theme.colors.primary}
          />
          <Text style={styles.roleText}>{profile.role === 'parent' ? 'Parent' : 'Helper'}</Text>
        </View>
      </View>

      <FlatList
        data={[...openRequests, ...claimedRequests]}
        renderItem={renderRequest}
        keyExtractor={(item: any) => `request-${item.id}`}
        contentContainerStyle={styles.listContent}
        getItemLayout={(data, index) => ({
          length: 230,
          offset: 230 * index,
          index,
        })}
        refreshControl={<RefreshControl refreshing={false} tintColor={theme.colors.primary} />}
        ListHeaderComponent={
          openRequests.length > 0 ? (
            <Text style={styles.sectionTitle}>
              {openRequests.length} request{openRequests.length !== 1 ? 's' : ''} need help
            </Text>
          ) : null
        }
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Ionicons name="heart-outline" size={64} color={theme.colors.gray.medium} />
            <Text style={styles.emptyTitle}>No requests yet</Text>
            <Text style={styles.emptyText}>
              {profile.role === 'parent'
                ? 'Tap the + button to create your first help request'
                : 'Check back soon for help requests from parents'}
            </Text>
          </View>
        }
        removeClippedSubviews={true}
        maxToRenderPerBatch={5}
        windowSize={10}
        initialNumToRender={5}
        legacyImplementation={false}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
  },
  header: {
    padding: 20,
    backgroundColor: theme.colors.white,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.gray.light,
  },
  headerTop: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  greeting: {
    fontSize: theme.fontSizes.xl,
    fontWeight: '700',
    color: theme.colors.text.primary,
  },
  villageName: {
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text.secondary,
    marginTop: 2,
  },
  roleBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: theme.colors.background,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    gap: 4,
  },
  roleText: {
    fontSize: theme.fontSizes.xs,
    color: theme.colors.primary,
    fontWeight: '500',
  },
  listContent: {
    padding: 16,
    paddingBottom: 100,
  },
  sectionTitle: {
    fontSize: theme.fontSizes.lg,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginBottom: 12,
  },
  card: {
    backgroundColor: theme.colors.white,
    borderRadius: 20, // More rounded as per mockup
    padding: 16,
    marginBottom: 12,
    shadowColor: theme.colors.primary,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 12,
    elevation: 3,
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.03)',
  },
  cardClaimed: {
    opacity: 0.8,
    backgroundColor: theme.colors.gray.light + '40',
  },
  cardRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  categoryIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
  },
  categoryOpen: {
    borderColor: theme.colors.primary,
    backgroundColor: theme.colors.primary + '10', // 10% opacity primary
  },
  categoryClaimed: {
    borderColor: theme.colors.status.claimed,
    backgroundColor: theme.colors.status.claimed + '10',
  },
  cardContent: {
    flex: 1,
    gap: 2,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: theme.colors.text.primary,
  },
  dateTime: {
    fontSize: 13,
    color: theme.colors.text.secondary,
    fontWeight: '500',
  },
  userRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 2,
  },
  postedBy: {
    fontSize: 12,
    color: theme.colors.text.secondary,
  },
  cardRight: {
    alignItems: 'center',
    gap: 8,
  },
  miniChatBtn: {
    padding: 6,
    backgroundColor: theme.colors.primary + '15',
    borderRadius: 8,
  },
  claimButton: {
    backgroundColor: theme.colors.primary,
    borderRadius: 12,
    paddingVertical: 10,
    alignItems: 'center',
    marginTop: 12,
  },
  claimButtonText: {
    color: theme.colors.white,
    fontSize: 14,
    fontWeight: '700',
  },
  emptyContainer: {
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyTitle: {
    fontSize: theme.fontSizes.xl,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginTop: 16,
  },
  emptyText: {
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text.secondary,
    textAlign: 'center',
    marginTop: 8,
    paddingHorizontal: 32,
    lineHeight: 22,
  },
});