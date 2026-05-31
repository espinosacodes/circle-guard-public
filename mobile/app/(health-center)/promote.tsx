/**
 * CG-012 - Health Center "promote suspect → confirmed" screen.
 *
 * Demo-grade UI: just enough to prove the form exists, hits the
 * `/api/v1/promotion/health-center/promote` endpoint, and surfaces the
 * 202 correlationId / 422 validation error. Production UX work is
 * tracked separately — see the banner at the top of the screen.
 */
import { useState } from 'react';
import {
    View,
    Text,
    TextInput,
    StyleSheet,
    TouchableOpacity,
    Alert,
    ActivityIndicator,
    ScrollView,
} from 'react-native';
import { useAuth } from '@/context/AuthContext';

const API_BASE =
    process.env.EXPO_PUBLIC_PROMOTION_URL ?? 'http://localhost:8088';

export default function HealthCenterPromoteScreen() {
    const { token } = useAuth();
    const [suspectHashId, setSuspectHashId] = useState('');
    const [evidenceUrl, setEvidenceUrl]     = useState('');
    const [reason, setReason]               = useState('');
    const [submitting, setSubmitting]       = useState(false);
    const [lastCorrelationId, setLastCorrelationId] = useState<string | null>(null);

    const submit = async () => {
        if (!suspectHashId || !evidenceUrl || !reason) {
            Alert.alert('Missing fields', 'All three fields are required.');
            return;
        }
        setSubmitting(true);
        setLastCorrelationId(null);
        try {
            const res = await fetch(
                `${API_BASE}/api/v1/promotion/health-center/promote`,
                {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        ...(token ? { Authorization: `Bearer ${token}` } : {}),
                    },
                    body: JSON.stringify({ suspectHashId, evidenceUrl, reason }),
                }
            );

            if (res.status === 202) {
                const body = await res.json();
                setLastCorrelationId(body.correlationId);
                Alert.alert(
                    'Promotion accepted',
                    `Correlation id: ${body.correlationId}\n\nNotifications will fan out shortly.`
                );
                setSuspectHashId('');
                setEvidenceUrl('');
                setReason('');
            } else if (res.status === 422) {
                Alert.alert(
                    'Real name detected',
                    'Anonymity policy: do not include first + last names in the reason or evidence URL.'
                );
            } else if (res.status === 401 || res.status === 403) {
                Alert.alert(
                    'Not authorised',
                    'Your account is missing the HEALTH_CENTER_OFFICER role.'
                );
            } else {
                Alert.alert(
                    'Unexpected response',
                    `Status ${res.status}. Please retry or escalate to platform-on-call.`
                );
            }
        } catch (e: any) {
            Alert.alert('Network error', e?.message ?? 'Could not reach promotion-service.');
        } finally {
            setSubmitting(false);
        }
    };

    return (
        <ScrollView style={styles.container} contentContainerStyle={styles.content}>
            <View style={styles.banner}>
                <Text style={styles.bannerText}>
                    Demo screen — production UI will require additional UX work.
                </Text>
            </View>

            <Text style={styles.title}>Promote Suspect to Confirmed</Text>
            <Text style={styles.subtitle}>
                Health Center officers only. Submissions emit a `promotion.confirmed`
                Kafka event with a correlation id you can trace through
                `/api/v1/notifications/by-correlation/&lt;id&gt;`.
            </Text>

            <Text style={styles.label}>Suspect Hash ID</Text>
            <TextInput
                style={styles.input}
                value={suspectHashId}
                onChangeText={setSuspectHashId}
                autoCapitalize="none"
                placeholder="anon-abc-123"
            />

            <Text style={styles.label}>Evidence URL</Text>
            <TextInput
                style={styles.input}
                value={evidenceUrl}
                onChangeText={setEvidenceUrl}
                autoCapitalize="none"
                placeholder="https://s3.amazonaws.com/cg-evidence/r-2024-001.pdf"
                autoCorrect={false}
            />

            <Text style={styles.label}>Reason (no real names)</Text>
            <TextInput
                style={[styles.input, styles.multiline]}
                value={reason}
                onChangeText={setReason}
                multiline
                numberOfLines={4}
                placeholder="PCR result attached - sample collected 2024-05-30"
            />

            <TouchableOpacity
                style={[styles.button, submitting && styles.buttonDisabled]}
                onPress={submit}
                disabled={submitting}
            >
                {submitting ? (
                    <ActivityIndicator color="#ffffff" />
                ) : (
                    <Text style={styles.buttonText}>Submit Promotion</Text>
                )}
            </TouchableOpacity>

            {lastCorrelationId && (
                <View style={styles.correlationBox}>
                    <Text style={styles.correlationLabel}>Last correlation id:</Text>
                    <Text style={styles.correlationValue}>{lastCorrelationId}</Text>
                </View>
            )}
        </ScrollView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#09090b',
    },
    content: {
        padding: 24,
        paddingBottom: 64,
    },
    banner: {
        backgroundColor: 'rgba(234, 179, 8, 0.15)',
        borderColor: 'rgba(234, 179, 8, 0.4)',
        borderWidth: 1,
        padding: 12,
        borderRadius: 8,
        marginBottom: 24,
    },
    bannerText: {
        color: '#fef08a',
        fontSize: 13,
        fontWeight: '600',
        textAlign: 'center',
    },
    title: {
        color: '#f4f4f5',
        fontSize: 24,
        fontWeight: '700',
        marginBottom: 8,
    },
    subtitle: {
        color: '#a1a1aa',
        fontSize: 14,
        lineHeight: 20,
        marginBottom: 24,
    },
    label: {
        color: '#d4d4d8',
        fontSize: 13,
        fontWeight: '600',
        marginBottom: 6,
        marginTop: 12,
        textTransform: 'uppercase',
        letterSpacing: 0.5,
    },
    input: {
        backgroundColor: '#18181b',
        borderColor: '#3f3f46',
        borderWidth: 1,
        borderRadius: 8,
        padding: 12,
        color: '#f4f4f5',
        fontSize: 15,
    },
    multiline: {
        minHeight: 96,
        textAlignVertical: 'top',
    },
    button: {
        marginTop: 32,
        backgroundColor: '#0891B2',
        paddingVertical: 16,
        borderRadius: 12,
        alignItems: 'center',
    },
    buttonDisabled: {
        opacity: 0.6,
    },
    buttonText: {
        color: '#ffffff',
        fontSize: 16,
        fontWeight: '700',
        letterSpacing: 0.5,
    },
    correlationBox: {
        marginTop: 24,
        padding: 12,
        backgroundColor: '#18181b',
        borderRadius: 8,
        borderWidth: 1,
        borderColor: '#3f3f46',
    },
    correlationLabel: {
        color: '#71717a',
        fontSize: 12,
        fontWeight: '600',
        marginBottom: 4,
    },
    correlationValue: {
        color: '#22d3ee',
        fontSize: 13,
        fontFamily: 'monospace',
    },
});
