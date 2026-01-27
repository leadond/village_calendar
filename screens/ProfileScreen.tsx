import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Share,
  Platform,
  TextInput,
  ScrollView,
  ActivityIndicator,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAuth } from '@clerk/clerk-expo';
import { useMutation, useQuery } from 'convex/react';
import { api } from '../convex/_generated/api';

import { theme } from '../lib/theme';
import { Ionicons } from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import Avatar from '../components/Avatar';

interface Props {
  profile: {
    name: string;
    role: 'parent' | 'helper';
    villageId: any;
    villageName: string;
    villageCode: string;
    photoUrl?: string | null;
    status?: 'active' | 'pending' | 'rejected';
  };
  navigation?: any;
}

export default function ProfileScreen({ profile, navigation }: Props) {
  const [sharingInvite, setSharingInvite] = useState(false);
  const { signOut } = useAuth();
  const members = useQuery(api.villages.getVillageMembers, { villageId: profile.villageId });

  // Pending approvals
  const pendingMembers = useQuery(api.villages.getPendingMembers, { villageId: profile.villageId });
  const approveMember = useMutation(api.villages.approveMember);
  const rejectMember = useMutation(api.villages.rejectMember);

  const adminStatus = useQuery(api.adminAuth.getAdminStatus, {});
  const bootstrapOwner = useMutation(api.adminAuth.bootstrapOwner);
  const createInvite = useMutation(api.invites.createInvite);

  // Multi-village support
  const myVillages = useQuery(api.profiles.getMyVillages, {});
  const switchVillage = useMutation(api.profiles.switchVillage);
  const joinVillageByCode = useMutation(api.profiles.joinVillageByCode);
  const [switching, setSwitching] = useState(false);

  // Join modal state
  const [joinCode, setJoinCode] = useState("");
  const [isJoining, setIsJoining] = useState(false);

  // Photo Upload
  const generateUploadUrl = useMutation(api.profiles.generateUploadUrl);
  const updateProfilePhoto = useMutation(api.profiles.updateProfilePhoto);
  const [uploadingPhoto, setUploadingPhoto] = useState(false);

  const handleUpdatePhoto = async () => {
    try {
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        aspect: [1, 1],
        quality: 0.8,
      });

      if (!result.canceled) {
        setUploadingPhoto(true);
        const { uri } = result.assets[0];

        // 1. Get upload URL
        const postUrl = await generateUploadUrl();

        // 2. Upload image
        const response = await fetch(uri);
        const blob = await response.blob();

        await fetch(postUrl, {
          method: "POST",
          headers: { "Content-Type": blob.type },
          body: blob,
        });

        // 3. Save storage ID
        const { storageId } = await (await fetch(postUrl, {
          method: "POST",
          headers: { "Content-Type": blob.type },
          body: blob,
        }).then(r => r.json()));

        // Wait, the standard way is:
        // The result of the upload (to the generated URL) returns the storageId?
        // No, Convex `generateUploadUrl` returns a URL. You POST the blob to it.
        // It returns JSON { storageId: ... }.

        const uploadResult = await fetch(postUrl, {
          method: "POST",
          headers: { "Content-Type": blob.type },
          body: blob,
        });

        if (!uploadResult.ok) {
          throw new Error(`Upload failed: ${uploadResult.statusText}`);
        }

        const { storageId: newStorageId } = await uploadResult.json();

        await updateProfilePhoto({ storageId: newStorageId });
        Alert.alert("Success", "Profile photo updated!");
      }
    } catch (error: any) {
      console.error("Photo upload error:", error);
      Alert.alert("Error", "Failed to upload photo");
    } finally {
      setUploadingPhoto(false);
    }
  };

  const handleShareInvite = async () => {
    try {
      if (sharingInvite) return;
      setSharingInvite(true);

      const invite = await createInvite({ villageId: profile.villageId });

      const mobileUrl = 'https://a0.dev/app/f3e1f932-1508-4895-9ece-4fc1a163c829';
      const webUrl = 'https://ehsstaffing-ac511.web.app';

      const message = `You're invited to join "${invite.villageName}" on Village Calendar!

Join via Web: ${webUrl}

Download App: ${mobileUrl}

Invite Code: ${invite.code}

Open the app → Sign up → Enter this invite code to join.`;

      await Share.share({
        title: 'Village Calendar Invite',
        message,
        url: webUrl,
      });
    } catch (error: any) {
      console.error(error);
      Alert.alert('Invite failed', error?.message ?? 'Could not create/share invite');
    } finally {
      setSharingInvite(false);
    }
  };

  const handleSwitchVillage = async (villageId: any) => {
    if (switching) return;
    setSwitching(true);
    try {
      await switchVillage({ villageId });
    } catch (e) {
      Alert.alert("Error", "Failed to switch village");
    } finally {
      setSwitching(false);
    }
  };

  const handleJoinVillage = async () => {
    if (!joinCode || joinCode.length < 6) {
      Alert.alert("Invalid Code", "Please enter a valid village code.");
      return;
    }
    setIsJoining(true);
    try {
      await joinVillageByCode({
        code: joinCode,
        role: 'helper',
        name: profile.name
      });

      Alert.alert("Success", "You have requested to join the village. A parent must approve you.");
      setJoinCode("");
    } catch (e: any) {
      Alert.alert("Error", e?.message ?? "Failed to join village");
    } finally {
      setIsJoining(false);
    }
  };

  const handleApprove = async (memberId: any, name: string) => {
    try {
      await approveMember({ profileId: memberId });
      Alert.alert("Approved", `${name} is now an active member.`);
    } catch (e) {
      Alert.alert("Error", "Failed to approve.");
    }
  };

  const handleReject = async (memberId: any) => {
    try {
      await rejectMember({ profileId: memberId });
    } catch (e) {
      Alert.alert("Error", "Failed to reject.");
    }
  };

  const handleLogout = async () => {
    console.log('handleLogout triggered');
    if (Platform.OS === 'web') {
      const confirm = window.confirm('Are you sure you want to sign out?');
      if (confirm) {
        await signOut();
        window.location.replace('/');
      }
      return;
    }

    Alert.alert('Sign Out', 'Are you sure you want to sign out?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Sign Out',
        style: 'destructive',
        onPress: async () => {
          await signOut();
        }
      },
    ]);
  };

  const handleBootstrapOwner = async () => {
    console.log("Claim Owner Access clicked");

    if (Platform.OS === 'web') {
      const confirm = window.confirm('Claim owner access?\n\nThis device/user will become the app owner admin. This can only be done once (first admin).');
      if (!confirm) return;

      try {
        await bootstrapOwner({});
        window.alert("Success! You are now the owner. The app will reload to update permissions.");
        window.location.reload();
      } catch (e: any) {
        console.error("Bootstrap owner failed:", e);
        window.alert(e?.message ?? 'Failed to claim ownership');
      }
      return;
    }

    Alert.alert(
      'Claim owner access?',
      'This device/user will become the app owner admin. This can only be done once (first admin).',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Claim Owner',
          style: 'default',
          onPress: async () => {
            try {
              await bootstrapOwner({});
              Alert.alert("Success", "You are now the owner.");
            } catch (e: any) {
              Alert.alert('Error', e?.message ?? 'Failed');
            }
          },
        },
      ]
    );
  };

  const parents = members?.filter((m: any) => m.role === 'parent') || [];
  const helpers = members?.filter((m: any) => m.role === 'helper') || [];

  return (
    <SafeAreaView style={styles.container} edges={['top']}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Profile</Text>
      </View>

      <ScrollView style={styles.content} contentContainerStyle={{ paddingBottom: 40 }} showsVerticalScrollIndicator={false}>
        {/* User Info */}
        <View style={styles.userSection}>
          <TouchableOpacity
            onPress={handleUpdatePhoto}
            disabled={uploadingPhoto}
            style={styles.avatarContainer}
            accessibilityLabel="Change profile photo"
            accessibilityRole="button"
          >
            <Avatar
              name={profile.name}
              uri={profile.photoUrl}
              size={100}
            />
            {uploadingPhoto ? (
              <View style={styles.loadingOverlay}>
                <ActivityIndicator color={theme.colors.white} />
              </View>
            ) : (
              <View style={styles.editBadge}>
                <Ionicons name="camera" size={14} color="white" />
              </View>
            )}
          </TouchableOpacity>
          <Text style={styles.userName}>{profile.name}</Text>
          <View style={styles.roleTag}>
            <Text style={styles.roleText}>{profile.role === 'parent' ? 'Parent' : 'Villager'}</Text>
          </View>
          {/* Status Banner for Pending Users */}
          {profile.status === 'pending' && (
            <View style={styles.pendingBanner}>
              <Text style={styles.pendingText}>Status: Pending Approval</Text>
            </View>
          )}
        </View>

        {/* Pending Approvals (Visible to Parents only) */}
        {profile.role === 'parent' && pendingMembers && pendingMembers.length > 0 && (
          <View style={styles.approvalSection}>
            <Text style={styles.sectionTitle}>Pending Approvals</Text>
            {pendingMembers.map((m: any) => (
              <View key={m.id} style={styles.approvalCard}>
                <View style={{ flex: 1, marginRight: 8 }}>
                  <Text style={styles.approvalName} numberOfLines={1} ellipsizeMode="tail">
                    {m.name}
                  </Text>
                  <Text style={styles.approvalRole}>Requesting to join as {m.role}</Text>
                </View>
                <View style={styles.approvalActions}>
                  <TouchableOpacity
                    onPress={() => handleApprove(m.id, m.name)}
                    style={styles.approveBtn}
                    accessibilityLabel="Approve"
                    accessibilityRole="button"
                  >
                    <Text style={{ color: 'white', fontWeight: 'bold', fontSize: 12 }}>Approve</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    onPress={() => handleReject(m.id)}
                    style={styles.rejectBtn}
                    accessibilityLabel="Reject"
                    accessibilityRole="button"
                  >
                    <Ionicons name="close" size={20} color="#ef4444" />
                  </TouchableOpacity>
                </View>
              </View>
            ))}
          </View>
        )}

        {/* Village Switcher */}
        {myVillages && myVillages.length > 1 && (
          <View style={styles.switcherSection}>
            <Text style={styles.sectionTitle}>Switch Village</Text>
            {myVillages.map((v: any) => (
              <TouchableOpacity
                key={v.villageId}
                style={[styles.villageOption, v.isActive && styles.activeVillageOption]}
                onPress={() => !v.isActive && handleSwitchVillage(v.villageId)}
                disabled={v.isActive || switching}
              >
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                  <Ionicons
                    name={v.role === 'parent' ? 'home' : 'heart'}
                    size={18}
                    color={v.isActive ? theme.colors.primary : theme.colors.text.secondary}
                  />
                  <Text style={[styles.villageOptionText, v.isActive && styles.activeVillageText]}>
                    {v.villageName}
                  </Text>
                </View>
                {v.isActive && <Ionicons name="checkmark-circle" size={20} color={theme.colors.primary} />}
              </TouchableOpacity>
            ))}
          </View>
        )}

        {/* Join Village Section */}
        <View style={styles.joinSection}>
          <Text style={styles.sectionTitle}>Join Another Village</Text>
          <View style={styles.joinInputContainer}>
            <TextInput
              style={styles.joinInput}
              placeholder="Enter Village Code"
              value={joinCode}
              onChangeText={setJoinCode}
              autoCapitalize="characters"
              maxLength={8}
            />
            <TouchableOpacity
              style={[styles.joinButton, (!joinCode || isJoining) && styles.disabledButton]}
              onPress={handleJoinVillage}
              disabled={!joinCode || isJoining}
            >
              <Text style={styles.joinButtonText}>{isJoining ? "..." : "Join"}</Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Village Info */}
        <View style={styles.villageSection}>
          <Text style={styles.sectionTitle}>My Village</Text>
          <View style={styles.villageCard}>
            <View style={styles.villageHeader}>
              <Text style={styles.villageName}>{profile.villageName}</Text>
              <TouchableOpacity
                style={styles.shareButton}
                onPress={handleShareInvite}
                disabled={sharingInvite}
                accessibilityLabel={sharingInvite ? "Sharing invite in progress" : "Share village invite"}
                accessibilityHint={sharingInvite ? "Please wait while we create your invite" : "Share your village invite with others"}
                accessibilityRole="button"
              >
                <Ionicons
                  name={sharingInvite ? 'time-outline' : 'share-outline'}
                  size={20}
                  color={sharingInvite ? theme.colors.gray.medium : theme.colors.primary}
                />
              </TouchableOpacity>
            </View>

            <View style={styles.codeContainer}>
              <Text style={styles.codeLabel}>Village Code (Admin)</Text>
              <Text style={styles.codeValue}>{profile.villageCode}</Text>
            </View>

            <View style={styles.membersRow}>
              <View style={styles.memberStat}>
                <Ionicons name="home" size={18} color={theme.colors.primary} />
                <Text style={styles.memberCount}>{parents.length} parent{parents.length !== 1 ? 's' : ''}</Text>
              </View>
              <View style={styles.memberStat}>
                <Ionicons name="heart" size={18} color={theme.colors.accent} />
                <Text style={styles.memberCount}>{helpers.length} helper{helpers.length !== 1 ? 's' : ''}</Text>
              </View>
            </View>
          </View>
        </View>

        {/* Actions */}
        <View style={styles.actionsSection}>
          {adminStatus?.role ? (
            <TouchableOpacity
              style={styles.actionButton}
              onPress={() => navigation?.navigate?.('Admin')}
              accessibilityLabel="Admin Tools"
              accessibilityHint="Access administrative tools and settings"
              accessibilityRole="button"
            >
              <Ionicons name="analytics-outline" size={22} color={theme.colors.text.primary} />
              <Text style={styles.actionText}>Admin Tools</Text>
              <Ionicons name="chevron-forward" size={20} color={theme.colors.gray.medium} />
            </TouchableOpacity>
          ) : adminStatus && !adminStatus.hasAnyAdmin ? (
            <TouchableOpacity
              style={styles.actionButton}
              onPress={handleBootstrapOwner}
              accessibilityLabel="Claim Owner Access"
              accessibilityHint="Become the app owner administrator for this village"
              accessibilityRole="button"
            >
              <Ionicons name="key-outline" size={22} color={theme.colors.text.primary} />
              <Text style={styles.actionText}>Claim Owner Access</Text>
              <Ionicons name="chevron-forward" size={20} color={theme.colors.gray.medium} />
            </TouchableOpacity>
          ) : null}

          <TouchableOpacity
            style={styles.actionButton}
            onPress={handleShareInvite}
            disabled={sharingInvite}
            accessibilityLabel="Invite to Village"
            accessibilityHint="Share an invitation to join your village"
            accessibilityRole="button"
          >
            <Ionicons name="person-add-outline" size={22} color={theme.colors.text.primary} />
            <Text style={styles.actionText}>Invite to Village</Text>
            <Ionicons name="chevron-forward" size={20} color={theme.colors.gray.medium} />
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.actionButton, styles.logoutButton]}
            onPress={handleLogout}
            accessibilityLabel="Sign Out"
            accessibilityHint="Sign out of your account and return to login screen"
            accessibilityRole="button"
          >
            <Ionicons name="log-out-outline" size={22} color={theme.colors.accent} />
            <Text style={[styles.actionText, styles.logoutText]}>Sign Out</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
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
    paddingBottom: 16,
    backgroundColor: theme.colors.white,
    borderBottomWidth: 1,
    borderBottomColor: theme.colors.gray.light,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: theme.colors.text.primary,
  },
  content: {
    flex: 1,
    padding: 20,
  },
  userSection: {
    alignItems: 'center',
    marginBottom: 32,
  },
  avatarContainer: {
    position: 'relative',
    marginBottom: 16,
    // Shadow for depth
    shadowColor: theme.colors.black,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 3,
  },
  editBadge: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    backgroundColor: theme.colors.primary,
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 3,
    borderColor: theme.colors.white,
  },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.3)',
    borderRadius: 50,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: theme.colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    fontSize: 32,
    color: theme.colors.white,
    fontWeight: 'bold',
  },
  userName: {
    fontSize: 24,
    fontWeight: 'bold',
    color: theme.colors.text.primary,
    marginBottom: 4,
  },
  roleTag: {
    paddingHorizontal: 12,
    paddingVertical: 4,
    backgroundColor: theme.colors.primaryLight,
    borderRadius: 12,
    marginTop: 4,
  },
  roleBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: theme.colors.primary,
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 16,
    gap: 6,
  },
  roleText: {
    fontSize: 14,
    color: theme.colors.white,
    fontWeight: '500',
  },
  villageSection: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginBottom: 12,
  },
  villageCard: {
    backgroundColor: theme.colors.white,
    borderRadius: 16,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  villageHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  villageName: {
    fontSize: 20,
    fontWeight: '600',
    color: theme.colors.text.primary,
  },
  shareButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: theme.colors.background,
    justifyContent: 'center',
    alignItems: 'center',
  },
  codeContainer: {
    backgroundColor: theme.colors.background,
    borderRadius: 12,
    padding: 12,
    alignItems: 'center',
    marginBottom: 16,
  },
  codeLabel: {
    fontSize: 12,
    color: theme.colors.text.secondary,
    marginBottom: 4,
  },
  codeValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: theme.colors.primary,
    letterSpacing: 4,
  },
  membersRow: {
    flexDirection: 'row',
    gap: 24,
  },
  memberStat: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  memberCount: {
    fontSize: 14,
    color: theme.colors.text.secondary,
  },
  actionsSection: {
    marginTop: 8,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: theme.colors.white,
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
  },
  actionText: {
    flex: 1,
    fontSize: 16,
    color: theme.colors.text.primary,
    marginLeft: 12,
  },
  logoutButton: {
    marginTop: 16,
  },
  logoutText: {
    color: theme.colors.accent,
  },
  switcherSection: {
    marginBottom: 24,
    width: '100%',
  },
  villageOption: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 14,
    borderRadius: 12,
    backgroundColor: theme.colors.white,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: 'transparent',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  activeVillageOption: {
    borderColor: theme.colors.primary,
    backgroundColor: '#F0F9FF', // Light blue tint
  },
  villageOptionText: {
    fontSize: 16,
    color: theme.colors.text.primary,
    fontWeight: '500',
  },
  activeVillageText: {
    color: theme.colors.primary,
    fontWeight: '600',
  },
  pendingBanner: {
    marginTop: 8,
    backgroundColor: '#fff7ed',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#fed7aa',
  },
  pendingText: {
    color: '#c2410c',
    fontSize: 14,
    fontWeight: '500',
  },
  approvalSection: {
    marginBottom: 24,
  },
  approvalCard: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: 'white',
    padding: 12,
    borderRadius: 12,
    marginBottom: 8,
    shadowColor: '#000',
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  approvalName: {
    fontSize: 16,
    fontWeight: '600',
    color: theme.colors.text.primary,
  },
  approvalRole: {
    fontSize: 13,
    color: theme.colors.text.secondary,
  },
  approvalActions: {
    flexDirection: 'row',
    gap: 8,
  },
  approveBtn: {
    backgroundColor: '#22c55e', // Success green
    borderRadius: 8,
    paddingHorizontal: 12,
    height: 36,
    justifyContent: 'center',
    alignItems: 'center',
  },
  rejectBtn: {
    backgroundColor: '#fee2e2',
    borderRadius: 8,
    width: 36,
    height: 36,
    justifyContent: 'center',
    alignItems: 'center',
  },
  joinSection: {
    marginBottom: 24,
  },
  joinInputContainer: {
    flexDirection: 'row',
    gap: 12,
  },
  joinInput: {
    flex: 1,
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 14,
    fontSize: 16,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  joinButton: {
    backgroundColor: theme.colors.primary,
    borderRadius: 12,
    paddingHorizontal: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  disabledButton: {
    opacity: 0.6,
  },
  joinButtonText: {
    color: 'white',
    fontWeight: '600',
  },
});