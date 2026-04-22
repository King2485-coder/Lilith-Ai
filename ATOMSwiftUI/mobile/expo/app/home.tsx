import { router } from "expo-router";
import React from "react";
import { Pressable, Text, TextInput, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, StatPill, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useSession } from "../providers/SessionProvider";

type UnifiedLoop = {
  overall_score: number;
  daily_remaining: number;
  active_stage?: string;
  habit?: {
    streak_count: number;
    level: number;
    progress_percent: number;
    dominant_action?: { action_type: string; title: string; subtitle: string; ref_id: string } | null;
  };
  next_actions: Array<{ action_type: string; title: string; subtitle: string; ref_id: string }>;
};

type SocialOverview = {
  friends_count: number;
  pending_requests: number;
  shared_goals: number;
  due_checkins: number;
  leaderboard_top: Array<{ rank: number; user: { id: string; username: string }; score: number; earnings: number }>;
  next_prompt: string;
};

type SocialFriend = {
  connection_id: string;
  status: string;
  direction: "incoming" | "outgoing";
  friend: { id: string; username: string };
};

type SocialGoal = {
  goal_id: string;
  title: string;
  description: string;
  daily_target: number;
  status: string;
  membership_status: "invited" | "accepted" | "declined";
  today_progress: number;
  members: Array<{ user: { id: string; username: string }; role: string; status: string }>;
};

type LeaderboardRow = {
  rank: number;
  user: { id: string; username: string };
  score: number;
  earnings: number;
  checkins: number;
  lessons: number;
};

type LiveEngagement = {
  live_presence: Array<{ user: { id: string; username: string }; status: string; activity_type: string; summary: string; updated_at: string }>;
  micro_celebrations: Array<{ id: string; user: { id: string; username: string }; activity_type: string; summary: string; score_delta: number; created_at: string }>;
  chase_mode: {
    current_rank: number | null;
    score?: number;
    ahead?: { user: { id: string; username: string }; gap_score: number } | null;
    behind?: { user: { id: string; username: string }; lead_score: number } | null;
  };
  shared_goal_urgency: Array<{ goal_id: string; title: string; today_progress: number; daily_target: number; remaining: number }>;
  accountability_prompt: string;
};

type SocialPrivacy = {
  share_presence: boolean;
  share_earnings: boolean;
  allow_nudges: boolean;
};

type ReputationDashboard = {
  profile: {
    work_ethic_score: number;
    consistency_days: number;
    active_days_30: number;
    inactive_days_30: number;
    recovery_mode: boolean;
    social_visibility: "private" | "friends" | "public";
    business_trust_score: number;
    reliability_notes?: { status?: string; recovery_tip?: string; completion_ratio?: number };
  };
  badges: Array<{ id: string; code: string; title: string; description: string; earned_at: string }>;
};

type SocialReputation = {
  items: Array<{
    user: { id: string; username: string };
    work_ethic_score: number;
    consistency_days: number;
    business_trust_score: number;
    recovery_mode: boolean;
  }>;
};

type RealWorldDashboard = {
  connectors: Array<{ id: string; connector_type: string; provider: string; status: string; scopes: string[] }>;
  opportunity_count: number;
  pending_applications: number;
  pending_pipelines: number;
  income_summary: { total_30d_usd: number; event_count: number };
  allocation_suggestion: { allocations: { essentials: number; savings: number; tax: number; reinvest: number } };
};

type RealWorldOpportunity = {
  id: string;
  title: string;
  description: string;
  category: string;
  payout_min: number;
  payout_max: number;
  location_mode: string;
  verified: boolean;
  scam_risk_score: number;
};

export default function HomeScreen() {
  const { apiBase, token } = useSession();
  const [loop, setLoop] = React.useState<UnifiedLoop | null>(null);
  const [socialOverview, setSocialOverview] = React.useState<SocialOverview | null>(null);
  const [friends, setFriends] = React.useState<SocialFriend[]>([]);
  const [goals, setGoals] = React.useState<SocialGoal[]>([]);
  const [leaderboard, setLeaderboard] = React.useState<LeaderboardRow[]>([]);
  const [live, setLive] = React.useState<LiveEngagement | null>(null);
  const [privacy, setPrivacy] = React.useState<SocialPrivacy | null>(null);
  const [friendInput, setFriendInput] = React.useState("");
  const [goalInput, setGoalInput] = React.useState("Daily income sprint");
  const [socialStatus, setSocialStatus] = React.useState("Social synced.");
  const [reputation, setReputation] = React.useState<ReputationDashboard | null>(null);
  const [socialReputation, setSocialReputation] = React.useState<SocialReputation["items"]>([]);
  const [realWorld, setRealWorld] = React.useState<RealWorldDashboard | null>(null);
  const [jobOpportunities, setJobOpportunities] = React.useState<RealWorldOpportunity[]>([]);
  const [reputationStatus, setReputationStatus] = React.useState("Reputation synced.");
  const [realWorldStatus, setRealWorldStatus] = React.useState("Real-world layer synced.");
  const [checkinStatus, setCheckinStatus] = React.useState("How did Lilith feel today?");

  const refreshLoop = React.useCallback(async () => {
    try {
      const [res, overview, friendsRes, goalsRes, boardRes, liveRes, privacyRes] = await Promise.all([
        apiRequest<UnifiedLoop>(apiBase, token, "/api/v1/income-engine/unified-loop"),
        apiRequest<SocialOverview>(apiBase, token, "/api/v1/social/overview"),
        apiRequest<{ items: SocialFriend[] }>(apiBase, token, "/api/v1/social/friends"),
        apiRequest<{ items: SocialGoal[] }>(apiBase, token, "/api/v1/social/goals"),
        apiRequest<{ items: LeaderboardRow[] }>(apiBase, token, "/api/v1/social/leaderboard?scope=friends&days=7"),
        apiRequest<LiveEngagement>(apiBase, token, "/api/v1/social/live-engagement"),
        apiRequest<SocialPrivacy>(apiBase, token, "/api/v1/social/privacy"),
      ]);
      setLoop(res);
      setSocialOverview(overview);
      setFriends(friendsRes.items || []);
      setGoals(goalsRes.items || []);
      setLeaderboard(boardRes.items || []);
      setLive(liveRes);
      setPrivacy(privacyRes);
      setSocialStatus("Social synced.");
    } catch {
      setLoop(null);
      setSocialStatus("Social sync unavailable.");
    }
  }, [apiBase, token]);

  const refreshReputation = React.useCallback(async () => {
    try {
      const [rep, socialRep] = await Promise.all([
        apiRequest<ReputationDashboard>(apiBase, token, "/api/v1/reputation/dashboard"),
        apiRequest<SocialReputation>(apiBase, token, "/api/v1/reputation/social"),
      ]);
      setReputation(rep);
      setSocialReputation(socialRep.items || []);
      setReputationStatus("Reputation synced.");
    } catch {
      setReputationStatus("Reputation unavailable.");
    }
  }, [apiBase, token]);

  const refreshRealWorld = React.useCallback(async () => {
    try {
      const [dash, jobs] = await Promise.all([
        apiRequest<RealWorldDashboard>(apiBase, token, "/api/v1/real-world/dashboard"),
        apiRequest<{ items: RealWorldOpportunity[] }>(apiBase, token, "/api/v1/real-world/jobs/search?limit=5"),
      ]);
      setRealWorld(dash);
      setJobOpportunities(jobs.items || []);
      setRealWorldStatus("Real-world layer synced.");
    } catch {
      setRealWorldStatus("Real-world layer unavailable.");
    }
  }, [apiBase, token]);

  React.useEffect(() => {
    refreshLoop();
    refreshReputation();
    refreshRealWorld();
  }, [refreshLoop, refreshReputation, refreshRealWorld]);

  React.useEffect(() => {
    const timer = setInterval(() => {
      refreshLoop();
      refreshReputation();
      refreshRealWorld();
    }, 15000);
    return () => clearInterval(timer);
  }, [refreshLoop, refreshReputation, refreshRealWorld]);

  const runLoopAction = React.useCallback(
    async (actionType: string, refId: string) => {
      if (actionType === "open_applications") {
        router.push("/application-builder");
        return;
      }
      try {
        await apiRequest(apiBase, token, "/api/v1/income-engine/unified-loop/advance", "POST", {
          action_type: actionType,
          ref_id: refId,
          confirm: actionType === "start_opportunity",
        });
        await refreshLoop();
      } catch {
        if (actionType.includes("opportunity")) {
          router.push("/wallet");
        }
      }
    },
    [apiBase, token, refreshLoop]
  );

  const requestFriend = React.useCallback(async () => {
    if (!friendInput.trim()) return;
    try {
      await apiRequest(apiBase, token, "/api/v1/social/friends/request", "POST", { username: friendInput.trim() });
      setFriendInput("");
      setSocialStatus("Friend request sent.");
      await refreshLoop();
    } catch {
      setSocialStatus("Unable to send friend request.");
    }
  }, [apiBase, token, friendInput, refreshLoop]);

  const respondFriend = React.useCallback(
    async (connectionId: string, decision: "accept" | "decline") => {
      try {
        await apiRequest(apiBase, token, "/api/v1/social/friends/respond", "POST", {
          connection_id: connectionId,
          decision,
        });
        setSocialStatus(decision === "accept" ? "Friend request accepted." : "Friend request declined.");
        await refreshLoop();
      } catch {
        setSocialStatus("Unable to update friend request.");
      }
    },
    [apiBase, token, refreshLoop]
  );

  const createGoal = React.useCallback(async () => {
    if (!goalInput.trim()) return;
    try {
      const acceptedFriends = friends.filter((x) => x.status === "accepted").slice(0, 2).map((x) => x.friend.username);
      await apiRequest(apiBase, token, "/api/v1/social/goals", "POST", {
        title: goalInput.trim(),
        description: "Shared accountability goal from Lilith Home.",
        daily_target: 300,
        member_usernames: acceptedFriends,
      });
      setSocialStatus("Shared goal created.");
      await refreshLoop();
    } catch {
      setSocialStatus("Unable to create shared goal.");
    }
  }, [apiBase, token, goalInput, friends, refreshLoop]);

  const quickCheckin = React.useCallback(async () => {
    const acceptedGoal = goals.find((x) => x.membership_status === "accepted");
    if (!acceptedGoal) return;
    try {
      await apiRequest(apiBase, token, `/api/v1/social/goals/${acceptedGoal.goal_id}/checkin`, "POST", {
        note: "Progress update from Lilith Home.",
        progress_amount: 25,
      });
      setSocialStatus("Accountability check-in posted.");
      await refreshLoop();
    } catch {
      setSocialStatus("Unable to post check-in.");
    }
  }, [apiBase, token, goals, refreshLoop]);

  const sendNudge = React.useCallback(
    async (toUserId: string, goalId: string) => {
      try {
        await apiRequest(apiBase, token, "/api/v1/social/nudges/send", "POST", {
          to_user_id: toUserId,
          goal_id: goalId,
          message: "Quick momentum check. You’re close today.",
        });
        setSocialStatus("Accountability nudge sent.");
        await refreshLoop();
      } catch {
        setSocialStatus("Unable to send nudge.");
      }
    },
    [apiBase, token, refreshLoop]
  );

  const patchPrivacy = React.useCallback(
    async (patch: Partial<SocialPrivacy>) => {
      try {
        const res = await apiRequest<SocialPrivacy>(apiBase, token, "/api/v1/social/privacy", "PATCH", patch);
        setPrivacy(res);
        setSocialStatus("Privacy updated.");
      } catch {
        setSocialStatus("Unable to update privacy.");
      }
    },
    [apiBase, token]
  );

  const logReputationWin = React.useCallback(async () => {
    try {
      await apiRequest(apiBase, token, "/api/v1/reputation/events", "POST", {
        event_type: "manual_consistency_win",
        completed: true,
        consistency_points: 1.5,
        misses: 0,
      });
      setReputationStatus("Consistency logged.");
      await refreshReputation();
    } catch {
      setReputationStatus("Unable to log consistency.");
    }
  }, [apiBase, token, refreshReputation]);

  const enableRecovery = React.useCallback(async () => {
    try {
      await apiRequest(apiBase, token, "/api/v1/reputation/recovery", "POST");
      setReputationStatus("Recovery mode enabled.");
      await refreshReputation();
    } catch {
      setReputationStatus("Unable to enable recovery.");
    }
  }, [apiBase, token, refreshReputation]);

  const applyToOpportunity = React.useCallback(
    async (opportunityId: string) => {
      try {
        await apiRequest(apiBase, token, "/api/v1/real-world/jobs/apply", "POST", {
          opportunity_id: opportunityId,
          use_autofill: true,
          confirm_submit: false,
          proposal_text: "",
        });
        setRealWorldStatus("Application prepared. Confirming submit...");
        await apiRequest(apiBase, token, "/api/v1/real-world/jobs/apply", "POST", {
          opportunity_id: opportunityId,
          use_autofill: true,
          confirm_submit: true,
          proposal_text: "Generated from Lilith real-world flow.",
        });
        setRealWorldStatus("Application submitted.");
        await Promise.all([refreshRealWorld(), refreshReputation()]);
      } catch {
        setRealWorldStatus("Unable to apply right now.");
      }
    },
    [apiBase, token, refreshRealWorld, refreshReputation]
  );

  const prepareSavingsTransfer = React.useCallback(async () => {
    try {
      await apiRequest(apiBase, token, "/api/v1/real-world/payments/transfer/prepare", "POST", {
        amount: 50,
        destination: "savings",
        reason: "Income allocation from Lilith Home",
      });
      setRealWorldStatus("Transfer prepared for approval in Financial Hub.");
    } catch (error) {
      const detail = error instanceof Error ? error.message : "";
      if (detail.toLowerCase().includes("observe mode")) {
        setRealWorldStatus("Set Financial Access to Assist/Auto to prepare transfers.");
      } else {
        setRealWorldStatus("Unable to prepare transfer.");
      }
    }
  }, [apiBase, token]);

  const runPipelineDemo = React.useCallback(async () => {
    const firstOpportunity = jobOpportunities[0];
    if (!firstOpportunity) return;
    try {
      const created = await apiRequest<{ id: string }>(apiBase, token, "/api/v1/real-world/pipelines", "POST", {
        action_type: "jobs.apply_then_transfer",
        auto_execute: false,
        context: { surface: "home_canvas" },
        steps: [
          { type: "jobs.apply", sensitive: false, payload: { opportunity_id: firstOpportunity.id, use_autofill: true } },
          { type: "payments.prepare_transfer", sensitive: true, payload: { amount: 30, destination: "savings", reason: "Pipeline allocation" } },
        ],
      });
      await apiRequest(apiBase, token, `/api/v1/real-world/pipelines/${created.id}/execute`, "POST", { approve_sensitive: true });
      setRealWorldStatus("Pipeline executed with approval-gated payment step.");
      await refreshRealWorld();
    } catch {
      setRealWorldStatus("Pipeline execution failed.");
    }
  }, [apiBase, token, jobOpportunities, refreshRealWorld]);

  const submitDailyCheckin = React.useCallback(
    async (response: "smooth" | "confused" | "stuck") => {
      try {
        await apiRequest(apiBase, token, "/api/v1/first100/daily-checkin", "POST", {
          response,
          note:
            response === "smooth"
              ? "Flow felt easy."
              : response === "confused"
                ? "Some steps were unclear."
                : "Got blocked before completion.",
        });
        setCheckinStatus("Check-in saved. Thanks.");
      } catch {
        setCheckinStatus("Unable to save check-in right now.");
      }
    },
    [apiBase, token]
  );

  return (
    <EnvironmentShell
      screenKey="home"
      title="Lilith Home"
      subtitle="Your living command center: social, communication, wallet, and tools in one flow."
      leftActions={buildRailActions("left", "home")}
      rightActions={buildRailActions("right", "home")}
      bottomActions={buildRailActions("bottom", "home")}
    >
      <SurfaceScroll>
        <SectionCard title="Today Pulse" subtitle="Live activity across your Lilith OS">
          <View style={ui.rowWrap}>
            <StatPill label="Unread" value="12" />
            <StatPill label="Wallet" value="$4,280 + 90 USDC" />
            <StatPill label="Tool jobs" value="7 running" />
            <StatPill label="Calls" value="2 pending" />
          </View>
        </SectionCard>

        <SectionCard title="Daily Check-In" subtitle={checkinStatus}>
          <View style={ui.rowWrap}>
            <ActionChip label="Smooth" onPress={() => submitDailyCheckin("smooth")} />
            <ActionChip label="Confused" onPress={() => submitDailyCheckin("confused")} />
            <ActionChip label="Stuck" onPress={() => submitDailyCheckin("stuck")} />
          </View>
        </SectionCard>

        <SectionCard title="Quick Actions" subtitle="Start from intent, not app switching">
          <View style={ui.rowWrap}>
            {["Ask Lilith", "New Post", "Message", "Start Call", "Pay", "Open Tool", "Analyze Page"].map((item) => (
              <ActionChip key={item} label={item} />
            ))}
          </View>
        </SectionCard>

        <SectionCard title="Social Layer" subtitle={socialStatus}>
          <View style={ui.rowWrap}>
            <StatPill label="Friends" value={String(socialOverview?.friends_count || 0)} />
            <StatPill label="Pending" value={String(socialOverview?.pending_requests || 0)} />
            <StatPill label="Shared Goals" value={String(socialOverview?.shared_goals || 0)} />
            <StatPill label="Due Check-ins" value={String(socialOverview?.due_checkins || 0)} />
          </View>
          <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>{socialOverview?.next_prompt || "Invite a friend to begin."}</Text>
          <TextInput
            value={friendInput}
            onChangeText={setFriendInput}
            placeholder="@username"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <View style={ui.rowWrap}>
            <ActionChip label="Add Friend" onPress={requestFriend} />
            <ActionChip label="Check In Now" onPress={quickCheckin} />
          </View>
          {(friends || []).filter((x) => x.status === "pending" && x.direction === "incoming").slice(0, 3).map((row) => (
            <View key={row.connection_id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 5 }}>
              <Text style={ui.bodyText}>@{row.friend.username} sent a friend request.</Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Accept" onPress={() => respondFriend(row.connection_id, "accept")} />
                <ActionChip label="Decline" onPress={() => respondFriend(row.connection_id, "decline")} />
              </View>
            </View>
          ))}
          <TextInput
            value={goalInput}
            onChangeText={setGoalInput}
            placeholder="Shared goal title"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <View style={ui.rowWrap}>
            <ActionChip label="Create Shared Goal" onPress={createGoal} />
          </View>
          {(goals || []).slice(0, 3).map((goal) => (
            <View key={goal.goal_id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{goal.title}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                ${goal.today_progress.toFixed(2)} / ${goal.daily_target.toFixed(2)} today · {goal.membership_status}
              </Text>
            </View>
          ))}
          {(leaderboard || []).slice(0, 5).map((row) => (
            <View key={`${row.user.id}-${row.rank}`} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={ui.bodyText}>#{row.rank} @{row.user.username} · Score {row.score.toFixed(1)} · ${row.earnings.toFixed(0)}</Text>
            </View>
          ))}
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 6 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Live Presence</Text>
            {(live?.live_presence || []).slice(0, 4).map((item, idx) => (
              <Text key={`${item.user.id}-${idx}`} style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                @{item.user.username} · {item.status.replace("_", " ")} · {item.summary}
              </Text>
            ))}
          </View>
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 6 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Micro-Celebrations</Text>
            {(live?.micro_celebrations || []).slice(0, 4).map((item) => (
              <Text key={item.id} style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                @{item.user.username} {item.summary}
              </Text>
            ))}
          </View>
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 6 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Chase Mode</Text>
            <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
              Rank {live?.chase_mode?.current_rank ?? "-"} · Score {(live?.chase_mode?.score ?? 0).toFixed(1)}
            </Text>
            {live?.chase_mode?.ahead ? (
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                Ahead: @{live.chase_mode.ahead.user.username} by {live.chase_mode.ahead.gap_score.toFixed(1)}
              </Text>
            ) : null}
            {live?.chase_mode?.behind ? (
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                Behind: @{live.chase_mode.behind.user.username} by {live.chase_mode.behind.lead_score.toFixed(1)}
              </Text>
            ) : null}
          </View>
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 6 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Shared Goal Urgency</Text>
            <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>{live?.accountability_prompt || "Keep momentum with one update."}</Text>
            {(live?.shared_goal_urgency || []).slice(0, 2).map((goal) => {
              const targetFriend = friends.find((f) => f.status === "accepted")?.friend;
              return (
                <View key={goal.goal_id} style={{ gap: 4 }}>
                  <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>
                    {goal.title}: ${goal.remaining.toFixed(2)} remaining today
                  </Text>
                  <View style={ui.rowWrap}>
                    {targetFriend ? <ActionChip label={`Nudge @${targetFriend.username}`} onPress={() => sendNudge(targetFriend.id, goal.goal_id)} /> : null}
                  </View>
                </View>
              );
            })}
          </View>
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 6 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Privacy Controls</Text>
            <View style={ui.rowWrap}>
              <ActionChip label={`${privacy?.share_presence ? "• " : ""}Share Presence`} onPress={() => patchPrivacy({ share_presence: !privacy?.share_presence })} />
              <ActionChip label={`${privacy?.allow_nudges ? "• " : ""}Allow Nudges`} onPress={() => patchPrivacy({ allow_nudges: !privacy?.allow_nudges })} />
            </View>
          </View>
        </SectionCard>

        <SectionCard title="Reputation" subtitle={reputationStatus}>
          <View style={ui.rowWrap}>
            <StatPill label="Work Ethic" value={`${reputation?.profile.work_ethic_score?.toFixed(1) || "0.0"}`} />
            <StatPill label="Consistency" value={`${reputation?.profile.consistency_days || 0}d`} />
            <StatPill label="Biz Trust" value={`${reputation?.profile.business_trust_score?.toFixed(1) || "0.0"}`} />
            <StatPill label="30d Active" value={`${reputation?.profile.active_days_30 || 0}`} />
          </View>
          <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
            {(reputation?.profile.reliability_notes?.status || "building").replace("_", " ")} ·{" "}
            {reputation?.profile.reliability_notes?.recovery_tip || "Stay consistent to strengthen trust signals."}
          </Text>
          <View style={ui.rowWrap}>
            <ActionChip label="Log Consistency Win" onPress={logReputationWin} />
            <ActionChip label="Soft Recovery" onPress={enableRecovery} />
          </View>
          {(reputation?.badges || []).slice(0, 3).map((badge) => (
            <View key={badge.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{badge.title}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>{badge.description}</Text>
            </View>
          ))}
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Friends Reputation</Text>
            {(socialReputation || []).slice(0, 4).map((row) => (
              <Text key={row.user.id} style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                @{row.user.username} · ethic {row.work_ethic_score.toFixed(1)} · trust {row.business_trust_score.toFixed(1)}
              </Text>
            ))}
          </View>
        </SectionCard>

        <SectionCard title="Real-World Integration" subtitle={realWorldStatus}>
          <View style={ui.rowWrap}>
            <StatPill label="Connectors" value={`${realWorld?.connectors?.length || 0}`} />
            <StatPill label="Opportunities" value={`${realWorld?.opportunity_count || 0}`} />
            <StatPill label="Pending Apps" value={`${realWorld?.pending_applications || 0}`} />
            <StatPill label="30d Income" value={`$${(realWorld?.income_summary?.total_30d_usd || 0).toFixed(0)}`} />
          </View>
          <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
            Allocation suggestion: save ${realWorld?.allocation_suggestion?.allocations?.savings?.toFixed(0) || "0"} · tax $
            {realWorld?.allocation_suggestion?.allocations?.tax?.toFixed(0) || "0"}.
          </Text>
          <View style={ui.rowWrap}>
            <ActionChip label="Prepare Transfer (Approval)" onPress={prepareSavingsTransfer} />
            <ActionChip label="Run Chain Action" onPress={runPipelineDemo} />
          </View>
          {(jobOpportunities || []).slice(0, 3).map((job) => (
            <View key={job.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 5 }}>
              <Text style={ui.bodyText}>{job.title}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                {job.category} · ${job.payout_min.toFixed(0)}-${job.payout_max.toFixed(0)} · {job.location_mode}
              </Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Apply with Autofill" onPress={() => applyToOpportunity(job.id)} />
              </View>
            </View>
          ))}
        </SectionCard>

        <SectionCard title="Unified Improvement Loop" subtitle="Skills → Income → Financial → Applications → Skills">
          <View style={ui.rowWrap}>
            <StatPill label="Loop Score" value={`${Math.round((loop?.overall_score || 0) * 100)}%`} />
            <StatPill label="Daily Remaining" value={`$${(loop?.daily_remaining || 0).toFixed(2)}`} />
            <StatPill label="Streak" value={`${loop?.habit?.streak_count || 0}d`} />
            <StatPill label="Level" value={`L${loop?.habit?.level || 1}`} />
          </View>
          <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
            Active stage: {loop?.active_stage || "skills"} · Progress {Math.round(loop?.habit?.progress_percent || 0)}%
          </Text>
          <View style={ui.rowWrap}>
            <ActionChip label="Open Wallet Loop" onPress={() => router.push("/wallet")} />
            <ActionChip label="Refresh Loop" onPress={refreshLoop} />
          </View>
          {(loop?.next_actions || []).slice(0, 3).map((action, idx) => (
            <View key={`${action.action_type}-${idx}`} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 5 }}>
              <Text style={ui.bodyText}>{action.title}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>{action.subtitle}</Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Run" onPress={() => runLoopAction(action.action_type, action.ref_id)} />
              </View>
            </View>
          ))}
        </SectionCard>

        <SectionCard title="Environment Stream" subtitle="Social highlights, messages, and tool outputs">
          {[
            "Ari posted a new reel from Video Editor.",
            "Legal draft completed and ready to share.",
            "Payment request received from @orbitstudio.",
            "Guardian report generated for this week.",
          ].map((line) => (
            <Pressable key={line} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={ui.bodyText}>{line}</Text>
            </Pressable>
          ))}
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
