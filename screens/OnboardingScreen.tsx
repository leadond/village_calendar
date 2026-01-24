import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  ScrollView,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useMutation, useQuery } from 'convex/react';
import { api } from '../convex/_generated/api';

import { theme } from '../lib/theme';

import { Ionicons } from '@expo/vector-icons';

type Role = 'parent' | 'helper';

interface Props {
  route: {
    params?: {
      code?: string;
    };
  };
}

export default function OnboardingScreen({ route }: Props) {
  const createVillage = useMutation(api.villages.createVillage);
  const createProfile = useMutation(api.profiles.createProfile);

  const [step, setStep] = useState<'name' | 'role' | 'village'>('name');
  const [name, setName] = useState('');
  const [role, setRole] = useState<Role | null>(null);
  const [villageMode, setVillageMode] = useState<'create' | 'join' | null>(null);
  const [villageName, setVillageName] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (route.params?.code) {
      setInviteCode(route.params.code);
      setVillageMode('join');
    }
  }, [route.params?.code]);

  // Invite-only: lookup invite
  const invitePreview = useQuery(
    api.invites.getInvitePreview,
    inviteCode.length === 8 ? { code: inviteCode.toUpperCase() } : 'skip'
  );

  const handleContinueFromName = () => {
    if (!name.trim()) {
      Alert.alert('Error', 'Please enter your name');
      return;
    }
    setStep('role');
  };

  const handleSelectRole = (selectedRole: Role) => {
    setRole(selectedRole);
    setStep('village');
  };

  const handleFinish = async () => {
    if (!role || saving) return;

    setSaving(true);
    try {
      let villageId: any;

      if (villageMode === 'create') {
        if (!villageName.trim()) {
          Alert.alert('Error', 'Please enter a village name');
          setSaving(false);
          return;
        }
        villageId = await createVillage({ name: villageName.trim() });
      } else {
        if (!invitePreview) {
          Alert.alert('Error', 'Please enter a valid invite code');
          setSaving(false);
          return;
        }
        villageId = invitePreview.villageId;
      }

      await createProfile({
        name: name.trim(),
        role,
        villageId,
        inviteCode: villageMode === 'join' ? inviteCode.toUpperCase() : undefined,
      });

      // Don't set saving to false - let the profile query update trigger navigation
    } catch (error: any) {
      console.error('Onboarding error:', error);
      Alert.alert('Error', error?.message || 'Failed to complete setup');
      setSaving(false);
    }
  };

  const renderNameStep = () => (
    <View style={styles.stepContent}>
      <Text style={styles.stepTitle}>What's your name?</Text>
      <Text style={styles.stepSubtitle}>This is how others in your village will see you</Text>

      <TextInput
        style={styles.input}
        placeholder="Your name"
        value={name}
        onChangeText={setName}
        autoFocus
        placeholderTextColor={theme.colors.gray.medium}
        accessibilityLabel="Name input"
        accessibilityHint="Enter your full name"
      />

      <TouchableOpacity
        style={styles.button}
        onPress={handleContinueFromName}
        accessibilityRole="button"
        accessibilityLabel="Continue"
        accessibilityHint="Proceed to the next step"
      >
        <Text style={styles.buttonText}>Continue</Text>
      </TouchableOpacity>
    </View>
  );

  const renderRoleStep = () => (
    <View style={styles.stepContent}>
      <Text style={styles.stepTitle}>How will you use Village?</Text>
      <Text style={styles.stepSubtitle}>You can always change this later</Text>

      <TouchableOpacity
        style={[styles.roleCard, role === 'parent' && styles.roleCardSelected]}
        onPress={() => handleSelectRole('parent')}
        accessibilityRole="button"
        accessibilityLabel="I'm a Parent"
        accessibilityHint="Select this if you are a parent who will be posting help requests"
      >
        <View style={styles.roleIconContainer}>
          <Ionicons name="home" size={32} color={role === 'parent' ? theme.colors.white : theme.colors.primary} />
        </View>
        <View style={styles.roleInfo}>
          <Text style={[styles.roleTitle, role === 'parent' && styles.roleTextSelected]}>I'm a Parent</Text>
          <Text style={[styles.roleDescription, role === 'parent' && styles.roleTextSelected]}>
            Post help requests and coordinate with helpers
          </Text>
        </View>
      </TouchableOpacity>

      <TouchableOpacity
        style={[styles.roleCard, role === 'helper' && styles.roleCardSelected]}
        onPress={() => handleSelectRole('helper')}
        accessibilityRole="button"
        accessibilityLabel="I'm a Helper"
        accessibilityHint="Select this if you are a helper who will be volunteering to help families"
      >
        <View style={styles.roleIconContainer}>
          <Ionicons name="heart" size={32} color={role === 'helper' ? theme.colors.white : theme.colors.accent} />
        </View>
        <View style={styles.roleInfo}>
          <Text style={[styles.roleTitle, role === 'helper' && styles.roleTextSelected]}>I'm a Helper</Text>
          <Text style={[styles.roleDescription, role === 'helper' && styles.roleTextSelected]}>
            View requests and volunteer to help families
          </Text>
        </View>
      </TouchableOpacity>
    </View>
  );

  const renderVillageStep = () => (
    <View style={styles.stepContent}>
      <Text style={styles.stepTitle}>Join or create a village</Text>
      <Text style={styles.stepSubtitle}>Villages are private groups of families and helpers</Text>

      {!villageMode ? (
        <>
          <TouchableOpacity
            style={styles.optionCard}
            onPress={() => setVillageMode('join')}
            accessibilityRole="button"
            accessibilityLabel="Join an existing village"
            accessibilityHint="Navigates to the screen to enter an invite code"
          >
            <Ionicons name="people" size={28} color={theme.colors.primary} />
            <Text style={styles.optionText}>Join an existing village</Text>
            <Text style={styles.optionSubtext}>Enter an invite code</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.optionCard}
            onPress={() => setVillageMode('create')}
            accessibilityRole="button"
            accessibilityLabel="Create a new village"
            accessibilityHint="Navigates to the screen to create a new village"
          >
            <Ionicons name="add-circle" size={28} color={theme.colors.primary} />
            <Text style={styles.optionText}>Create a new village</Text>
            <Text style={styles.optionSubtext}>Start your own community</Text>
          </TouchableOpacity>
        </>
      ) : villageMode === 'join' ? (
        <>
          <TextInput
            style={[styles.input, styles.codeInput]}
            placeholder="INVITECODE"
            value={inviteCode}
            onChangeText={(text: string) => setInviteCode(text.toUpperCase().slice(0, 8))}
            maxLength={8}
            autoCapitalize="characters"
            placeholderTextColor={theme.colors.gray.medium}
            accessibilityLabel="Invite code input"
            accessibilityHint="Enter the 8-character invite code for the village you want to join"
          />

          {inviteCode.length === 8 && (
            <View style={styles.villagePreview}>
              {invitePreview === undefined ? (
                <ActivityIndicator color={theme.colors.primary} />
              ) : invitePreview === null ? (
                <Text style={styles.errorText}>No invite found with this code</Text>
              ) : (
                <Text style={styles.successText}>Invite to: {invitePreview.villageName}</Text>
              )}
            </View>
          )}

          <TouchableOpacity
            style={[styles.button, (!invitePreview || saving) && styles.buttonDisabled]}
            onPress={handleFinish}
            disabled={!invitePreview || saving}
            accessibilityRole="button"
            accessibilityLabel="Join Village"
            accessibilityHint="Joins the village associated with the invite code"
          >
            {saving ? (
              <ActivityIndicator color={theme.colors.white} />
            ) : (
              <Text style={styles.buttonText}>Join Village</Text>
            )}
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.backButton}
            onPress={() => setVillageMode(null)}
            accessibilityRole="button"
            accessibilityLabel="Back"
            accessibilityHint="Returns to the previous screen"
          >
            <Text style={styles.backText}>Back</Text>
          </TouchableOpacity>
        </>
      ) : (
        <>
          <TextInput
            style={styles.input}
            placeholder="Village name (e.g., Oak Street Families)"
            value={villageName}
            onChangeText={setVillageName}
            placeholderTextColor={theme.colors.gray.medium}
            accessibilityLabel="Village name input"
            accessibilityHint="Enter a name for your new village"
          />

          <TouchableOpacity
            style={[styles.button, (!villageName.trim() || saving) && styles.buttonDisabled]}
            onPress={handleFinish}
            disabled={!villageName.trim() || saving}
            accessibilityRole="button"
            accessibilityLabel="Create Village"
            accessibilityHint="Creates a new village with the name you entered"
          >
            {saving ? (
              <ActivityIndicator color={theme.colors.white} />
            ) : (
              <Text style={styles.buttonText}>Create Village</Text>
            )}
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.backButton}
            onPress={() => setVillageMode(null)}
            accessibilityRole="button"
            accessibilityLabel="Back"
            accessibilityHint="Returns to the previous screen"
          >
            <Text style={styles.backText}>Back</Text>
          </TouchableOpacity>
        </>
      )}
    </View>
  );

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <View style={styles.progress}>
          <View style={[styles.progressDot, step === 'name' && styles.progressDotActive]} />
          <View style={[styles.progressDot, step === 'role' && styles.progressDotActive]} />
          <View style={[styles.progressDot, step === 'village' && styles.progressDotActive]} />
        </View>

        {step === 'name' && renderNameStep()}
        {step === 'role' && renderRoleStep()}
        {step === 'village' && renderVillageStep()}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
  },
  scrollContent: {
    padding: 24,
    flexGrow: 1,
  },
  progress: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 8,
    marginBottom: 32,
  },
  progressDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: theme.colors.gray.light,
  },
  progressDotActive: {
    backgroundColor: theme.colors.primary,
    width: 24,
  },
  stepContent: {
    flex: 1,
  },
  stepTitle: {
    fontSize: theme.fontSizes.xl,
    fontWeight: 'bold',
    color: theme.colors.text.primary,
    marginBottom: 8,
  },
  stepSubtitle: {
    fontSize: theme.fontSizes.md,
    color: theme.colors.text.secondary,
    marginBottom: 32,
  },
  input: {
    backgroundColor: theme.colors.white,
    borderRadius: 12,
    padding: 16,
    fontSize: theme.fontSizes.md,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  codeInput: {
    fontSize: theme.fontSizes.xl,
    letterSpacing: 8,
    textAlign: 'center',
    fontWeight: '600',
  },
  button: {
    backgroundColor: theme.colors.primary,
    borderRadius: 12,
    height: 52,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 8,
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  buttonText: {
    color: theme.colors.white,
    fontSize: theme.fontSizes.lg,
    fontWeight: '600',
  },
  roleCard: {
    backgroundColor: theme.colors.white,
    borderRadius: 16,
    padding: 20,
    marginBottom: 16,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: theme.colors.gray.light,
  },
  roleCardSelected: {
    backgroundColor: theme.colors.primary,
    borderColor: theme.colors.primary,
  },
  roleIconContainer: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: theme.colors.background,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  roleInfo: {
    flex: 1,
  },
  roleTitle: {
    fontSize: theme.fontSizes.lg,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginBottom: 4,
  },
  roleDescription: {
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text.secondary,
  },
  roleTextSelected: {
    color: theme.colors.white,
  },
  optionCard: {
    backgroundColor: theme.colors.white,
    borderRadius: 16,
    padding: 20,
    marginBottom: 16,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  optionText: {
    fontSize: theme.fontSizes.lg,
    fontWeight: '600',
    color: theme.colors.text.primary,
    marginTop: 12,
  },
  optionSubtext: {
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text.secondary,
    marginTop: 4,
  },
  villagePreview: {
    padding: 16,
    alignItems: 'center',
  },
  successText: {
    fontSize: theme.fontSizes.md,
    color: theme.colors.status.claimed,
    fontWeight: '500',
  },
  errorText: {
    fontSize: theme.fontSizes.md,
    color: theme.colors.accent,
  },
  backButton: {
    marginTop: 16,
    alignItems: 'center',
  },
  backText: {
    fontSize: theme.fontSizes.md,
    color: theme.colors.text.secondary,
  },
});