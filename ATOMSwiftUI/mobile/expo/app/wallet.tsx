import { router } from "expo-router";
import React, { useCallback, useState } from "react";
import { Animated, Pressable, Text, TextInput, View } from "react-native";

import { EnvironmentShell } from "../components/EnvironmentShell";
import { ActionChip, SectionCard, StatPill, SurfaceScroll, buildRailActions, styles as ui } from "../components/LilithPrimitives";
import { browserTheme } from "../constants/colors";
import { apiRequest } from "../lib/api";
import { useCommandContext } from "../providers/CommandContextProvider";
import { useSession } from "../providers/SessionProvider";

type PaymentIntent = { id: string; amount: string; currency: string; status: string; created_at: string };
type Balance = { fiat_balance: string; usdc_balance: string };
type FinanceAccessPolicy = {
  access_level: "observe" | "assist" | "auto";
  max_transfer_limit: number;
  bill_runway_days: number;
  available_cash_buffer: number;
  require_biometric_sensitive: boolean;
  first_time_hard_confirm_required: boolean;
  one_click_trade_enabled: boolean;
  one_click_trade_max: number;
};

type FinanceDashboard = {
  access_policy: FinanceAccessPolicy;
  linked_accounts: Array<{ id: string; provider: string; display_name: string; account_type: string; status: string }>;
  opportunities: Array<{ id: string; title: string; type: string; impact_amount: number; confidence: number }>;
  automation_rules: Array<{ id: string; name: string; rule_type: string; enabled: boolean; require_approval: boolean }>;
};

type FinanceAnalysis = {
  cash_flow: { spend_30d: number; spend_previous_30d: number; trend_percent: number };
  opportunities: Array<{ type: string; title: string; impact_amount: number }>;
  spending_categories: Array<{ category: string; amount: number }>;
};

type ActionPreview = {
  id: string;
  action_type: string;
  status: string;
  reason: string;
  payload: { amount?: number; symbol?: string };
  guardrails: { blocked?: boolean; blocked_reasons?: string[] };
  requires_hard_confirmation: boolean;
  biometric_required: boolean;
  first_time_action: boolean;
};

type IncomeTargets = {
  daily_target: number;
  monthly_target: number;
  earnings_today: number;
  earnings_month: number;
  daily_progress: number;
  monthly_progress: number;
};

type IncomeProfile = {
  daily_target: number;
  monthly_target: number;
  skills: string[];
  location: string;
  availability_hours_per_day: number;
  preferred_categories: string[];
  risk_mode: "safe" | "balanced" | "growth";
  updated_at: string;
};

type IncomeOpportunity = {
  id: string;
  title: string;
  description: string;
  category: "task" | "freelance" | "gig" | "monetization";
  payout_min: number;
  payout_max: number;
  estimated_minutes: number;
  location_mode: "remote" | "local" | "hybrid";
  required_skills: string[];
  verified: boolean;
  scam_risk_score: number;
  scam_risk_level: "low" | "medium" | "high";
  match_score: number;
};

type IncomeAction = {
  id: string;
  opportunity_id: string;
  status: "started" | "applied" | "completed" | "declined";
  autofill_used: boolean;
  proposal_drafted: boolean;
  followup_scheduled: boolean;
  expected_payout: number;
  actual_payout: number;
  notes: Record<string, unknown>;
  created_at: string;
  updated_at: string;
};

type IncomeDashboard = {
  targets: IncomeTargets;
  profile: IncomeProfile;
  opportunities: IncomeOpportunity[];
  purchase_intelligence: {
    amount: number;
    month_spend: number;
    avg_daily_spend: number;
    projected_month_spend: number;
    warning: boolean;
    note: string;
  };
  credit_optimization: {
    utilization_estimate_percent: number;
    recommendation: string;
    status: string;
  };
  skills_engine: {
    skills: Array<{
      skill: string;
      proficiency: number;
      level: number;
      earnings_generated: number;
      attempts: number;
      completions: number;
      growth_score: number;
      last_used_at?: string | null;
    }>;
    skill_to_money_mapping: Array<{
      skill: string;
      opportunity_count: number;
      avg_payout: number;
      top_categories: string[];
      proficiency: number;
      earnings_generated: number;
    }>;
    earning_path: {
      remaining: number;
      summary: string;
      steps: Array<{
        opportunity_id: string;
        title: string;
        category: string;
        estimated_minutes: number;
        expected_payout: number;
      }>;
    };
    upgrades: Array<{
      lesson_id: string;
      skill: string;
      title: string;
      duration_minutes: number;
      difficulty: string;
      earning_impact: number;
      projected_proficiency_after: number;
    }>;
    progression: {
      current_level: string;
      next_level: string;
      remaining_to_next: number;
      next_threshold: number;
    };
  };
};

type IncomeStartPreview = {
  opportunity_id: string;
  title: string;
  estimated_payout_range: [number, number];
  estimated_minutes: number;
  autofill_fields: string[];
  requires_confirmation: boolean;
};

type UnifiedLoop = {
  overall_score: number;
  daily_remaining: number;
  stages: Array<{ key: string; label: string; score: number }>;
  active_stage?: string;
  habit?: {
    streak_count: number;
    engagement_points: number;
    progress_percent: number;
    level: number;
    dominant_action?: { action_type: string; title: string; subtitle: string; ref_id: string } | null;
    micro_rewards?: Array<{ event_type: string; title: string; xp: number; created_at: string }>;
  };
  metrics: {
    earnings_today: number;
    daily_target: number;
    cashflow_trend_percent: number;
    application_completion_rate: number;
  };
  next_actions: Array<{ action_type: string; title: string; subtitle: string; ref_id: string }>;
};

type MorningBrief = {
  streak_count: number;
  tone?: { preferred_tone: string; adaptive_tone: string };
  brief: {
    daily_goal: number;
    progress_today: number;
    dominant_action?: { action_type: string; title: string; subtitle: string; ref_id: string } | null;
    alerts: string[];
    simple_plan: string[];
  };
};

type ActiveGuidance = {
  tone?: { preferred_tone: string; adaptive_tone: string };
  dominant_action?: { action_type: string; title: string; subtitle: string; ref_id: string } | null;
  prompts: Array<{ label: string; action_type: string; ref_id: string }>;
  decision_support: Array<{ title: string; detail: string }>;
};

type EndOfDayReview = {
  tone?: { preferred_tone: string; adaptive_tone: string };
  earnings_today: number;
  daily_target: number;
  wins: string[];
  next_steps: string[];
};

type WeeklyCoach = {
  tone?: { preferred_tone: string; adaptive_tone: string };
  weekly_earnings: number;
  completed_actions: number;
  trend: string;
  daily_breakdown: Array<{ date: string; earnings: number }>;
  strategy: string[];
};

export default function WalletScreen() {
  const { apiBase, token } = useSession();
  const { setPreferredCurrency, setActiveConversationUserId } = useCommandContext();
  const [balance, setBalance] = useState<Balance | null>(null);
  const [history, setHistory] = useState<PaymentIntent[]>([]);
  const [receiverId, setReceiverId] = useState("");
  const [amount, setAmount] = useState("10");
  const [status, setStatus] = useState("Wallet ready.");
  const [paySuccess, setPaySuccess] = useState("");
  const [financeDashboard, setFinanceDashboard] = useState<FinanceDashboard | null>(null);
  const [financeAnalysis, setFinanceAnalysis] = useState<FinanceAnalysis | null>(null);
  const [previews, setPreviews] = useState<ActionPreview[]>([]);
  const [auditCount, setAuditCount] = useState(0);
  const [biometricApprove, setBiometricApprove] = useState(true);
  const [incomeDashboard, setIncomeDashboard] = useState<IncomeDashboard | null>(null);
  const [incomeOpportunities, setIncomeOpportunities] = useState<IncomeOpportunity[]>([]);
  const [incomeActions, setIncomeActions] = useState<IncomeAction[]>([]);
  const [incomeCategory, setIncomeCategory] = useState<"all" | "task" | "freelance" | "gig" | "monetization">("all");
  const [incomeSkillInput, setIncomeSkillInput] = useState("");
  const [incomeLocationInput, setIncomeLocationInput] = useState("");
  const [dailyTargetInput, setDailyTargetInput] = useState("300");
  const [pendingIncomePreview, setPendingIncomePreview] = useState<IncomeStartPreview | null>(null);
  const [pendingOpportunityId, setPendingOpportunityId] = useState("");
  const [optimizeHints, setOptimizeHints] = useState<Array<{ type: string; skill?: string; reason: string }>>([]);
  const [unifiedLoop, setUnifiedLoop] = useState<UnifiedLoop | null>(null);
  const [morningBrief, setMorningBrief] = useState<MorningBrief | null>(null);
  const [activeGuidance, setActiveGuidance] = useState<ActiveGuidance | null>(null);
  const [endReview, setEndReview] = useState<EndOfDayReview | null>(null);
  const [weeklyCoach, setWeeklyCoach] = useState<WeeklyCoach | null>(null);
  const [coachToneMode, setCoachToneMode] = useState<"supportive" | "direct" | "aggressive">("supportive");
  const payAnim = React.useRef(new Animated.Value(0)).current;

  React.useEffect(() => {
    setPreferredCurrency("USD");
  }, [setPreferredCurrency]);

  const refresh = useCallback(async () => {
    try {
      const [b, h, hub, previewRes, auditRes, incomeDash, incomeOpp, incomeAct, optimizeRes, loopRes, briefRes, activeRes, eodRes, weeklyRes, toneRes] = await Promise.all([
        apiRequest<Balance>(apiBase, token, "/api/v1/payments/balance"),
        apiRequest<PaymentIntent[]>(apiBase, token, "/api/v1/payments/history"),
        apiRequest<FinanceDashboard>(apiBase, token, "/api/v1/finance-hub/dashboard"),
        apiRequest<{ items: ActionPreview[] }>(apiBase, token, "/api/v1/finance-hub/actions/previews"),
        apiRequest<{ items: any[] }>(apiBase, token, "/api/v1/finance-hub/audit?limit=20"),
        apiRequest<IncomeDashboard>(apiBase, token, "/api/v1/income-engine/dashboard"),
        apiRequest<{ items: IncomeOpportunity[] }>(apiBase, token, `/api/v1/income-engine/opportunities?category=${incomeCategory}&limit=12`),
        apiRequest<{ items: IncomeAction[] }>(apiBase, token, "/api/v1/income-engine/actions"),
        apiRequest<{ items: Array<{ type: string; skill?: string; reason: string }> }>(apiBase, token, "/api/v1/income-engine/optimize"),
        apiRequest<UnifiedLoop>(apiBase, token, "/api/v1/income-engine/unified-loop"),
        apiRequest<MorningBrief>(apiBase, token, "/api/v1/income-engine/coach/morning-brief"),
        apiRequest<ActiveGuidance>(apiBase, token, "/api/v1/income-engine/coach/active-guidance"),
        apiRequest<EndOfDayReview>(apiBase, token, "/api/v1/income-engine/coach/end-of-day"),
        apiRequest<WeeklyCoach>(apiBase, token, "/api/v1/income-engine/coach/weekly"),
        apiRequest<{ tone_mode: "supportive" | "direct" | "aggressive" }>(apiBase, token, "/api/v1/income-engine/coach/tone"),
      ]);
      setBalance(b);
      setHistory(h);
      setFinanceDashboard(hub);
      setPreviews(previewRes.items || []);
      setAuditCount((auditRes.items || []).length);
      setIncomeDashboard(incomeDash);
      setIncomeOpportunities(incomeOpp.items || []);
      setIncomeActions(incomeAct.items || []);
      setOptimizeHints(optimizeRes.items || []);
      setUnifiedLoop(loopRes);
      setMorningBrief(briefRes);
      setActiveGuidance(activeRes);
      setEndReview(eodRes);
      setWeeklyCoach(weeklyRes);
      setCoachToneMode(toneRes.tone_mode || "supportive");
      if (!incomeSkillInput && (incomeDash.profile.skills || []).length) {
        setIncomeSkillInput(incomeDash.profile.skills.join(", "));
      }
      if (!incomeLocationInput && incomeDash.profile.location) {
        setIncomeLocationInput(incomeDash.profile.location);
      }
      if (!dailyTargetInput && incomeDash.targets.daily_target) {
        setDailyTargetInput(String(incomeDash.targets.daily_target));
      }
      setStatus("Balances synced.");
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, incomeCategory, incomeLocationInput, incomeSkillInput, dailyTargetInput]);

  const patchAccessLevel = useCallback(
    async (level: "observe" | "assist" | "auto") => {
      try {
        await apiRequest(apiBase, token, "/api/v1/finance-hub/access", "PATCH", { access_level: level });
        setStatus(`Access level updated to ${level}.`);
        await refresh();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, refresh]
  );

  const runAnalysis = useCallback(async () => {
    try {
      const analysis = await apiRequest<FinanceAnalysis>(apiBase, token, "/api/v1/finance-hub/analysis");
      setFinanceAnalysis(analysis);
      setStatus("Read-only financial analysis ready.");
      await refresh();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, refresh]);

  const previewSavingsMove = useCallback(async () => {
    try {
      await apiRequest(apiBase, token, "/api/v1/finance-hub/actions/preview", "POST", {
        action_type: "transfer_savings",
        amount: Number(amount || "0"),
        reason: "Suggest transfer to savings based on idle cash",
        source: "checking",
        destination: "savings",
      });
      setStatus("Action preview created. Review before approval.");
      await refresh();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, amount, refresh]);

  const previewTrade = useCallback(async () => {
    try {
      await apiRequest(apiBase, token, "/api/v1/finance-hub/actions/preview", "POST", {
        action_type: "trade",
        amount: Number(amount || "0"),
        symbol: "AAPL",
        reason: "Trade opportunity detected by Lilith",
      });
      setStatus("Trade preview created. Final approval required.");
      await refresh();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, amount, refresh]);

  const approvePreview = useCallback(
    async (previewId: string, mode: "standard" | "one_click" = "standard") => {
      try {
        await apiRequest(apiBase, token, `/api/v1/finance-hub/actions/${previewId}/approve`, "POST", {
          approve_mode: mode,
          biometric_ok: biometricApprove,
        });
        setStatus(mode === "one_click" ? "One-click approval submitted." : "Action approved.");
        await refresh();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, biometricApprove, refresh]
  );

  const declinePreview = useCallback(
    async (previewId: string) => {
      try {
        await apiRequest(apiBase, token, `/api/v1/finance-hub/actions/${previewId}/decline`, "POST", {
          reason: "User declined from wallet hub",
        });
        setStatus("Action declined.");
        await refresh();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, refresh]
  );

  const createAutomation = useCallback(
    async (ruleType: string) => {
      try {
        const config =
          ruleType === "fixed_after_payday"
            ? { amount: Number(amount || "0"), source: "checking", destination: "savings" }
            : ruleType === "round_up"
              ? { mode: "nearest_dollar" }
              : ruleType === "unusual_charge_alert"
                ? { threshold_multiplier: 2.5 }
                : { remind_days_before: 3 };
        await apiRequest(apiBase, token, "/api/v1/finance-hub/automations", "POST", {
          name: ruleType.replace(/_/g, " "),
          rule_type: ruleType,
          config,
          enabled: true,
          require_approval: true,
        });
        setStatus("Automation rule created.");
        await refresh();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, amount, refresh]
  );

  const runAutomation = useCallback(
    async (ruleId: string) => {
      try {
        await apiRequest(apiBase, token, `/api/v1/finance-hub/automations/${ruleId}/run`, "POST");
        setStatus("Automation executed with guardrails.");
        await refresh();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, refresh]
  );

  const coachEvent = useCallback(
    async (eventType: string, payload?: Record<string, unknown>) => {
      try {
        await apiRequest(apiBase, token, "/api/v1/income-engine/coach/event", "POST", {
          event_type: eventType,
          payload: payload || {},
        });
      } catch {
        // Coaching telemetry should never block user action.
      }
    },
    [apiBase, token]
  );

  const setCoachTone = useCallback(
    async (tone: "supportive" | "direct" | "aggressive") => {
      try {
        await apiRequest(apiBase, token, "/api/v1/income-engine/coach/tone", "PATCH", { tone_mode: tone });
        setCoachToneMode(tone);
        setStatus(`Coach tone set to ${tone}.`);
        await refresh();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, refresh]
  );

  const saveIncomeProfile = useCallback(async () => {
    try {
      const skills = incomeSkillInput
        .split(",")
        .map((x) => x.trim().toLowerCase())
        .filter(Boolean);
      await apiRequest(apiBase, token, "/api/v1/income-engine/profile", "PATCH", {
        daily_target: Number(dailyTargetInput || "300"),
        skills,
        location: incomeLocationInput.trim(),
      });
      setStatus("Income profile updated. Matching recalculated.");
      await refresh();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, dailyTargetInput, incomeSkillInput, incomeLocationInput, refresh]);

  const previewIncomeStart = useCallback(
    async (opportunityId: string) => {
      try {
        setPendingOpportunityId(opportunityId);
        const result = await apiRequest<{ status: "preview"; preview: IncomeStartPreview }>(
          apiBase,
          token,
          "/api/v1/income-engine/actions/start",
          "POST",
          {
            opportunity_id: opportunityId,
            confirm: false,
            autofill_profile: {
              location: incomeLocationInput.trim(),
              skills: incomeSkillInput
                .split(",")
                .map((x) => x.trim())
                .filter(Boolean)
                .slice(0, 8),
            },
          }
        );
        setPendingIncomePreview(result.preview);
        setStatus("Preview ready. Confirm to start.");
      } catch (error) {
        setStatus(String(error));
      } finally {
        setPendingOpportunityId("");
      }
    },
    [apiBase, token, incomeLocationInput, incomeSkillInput]
  );

  const confirmIncomeStart = useCallback(async () => {
    if (!pendingIncomePreview?.opportunity_id) return;
    try {
      const result = await apiRequest<{ status: "started"; action: IncomeAction }>(
        apiBase,
        token,
        "/api/v1/income-engine/actions/start",
        "POST",
        {
          opportunity_id: pendingIncomePreview.opportunity_id,
          confirm: true,
          autofill_profile: {
            location: incomeLocationInput.trim(),
            skills: incomeSkillInput
              .split(",")
              .map((x) => x.trim())
              .filter(Boolean)
              .slice(0, 8),
          },
        }
      );
      await coachEvent("opportunity_started", { title: "Opportunity started" });
      setPendingIncomePreview(null);
      setStatus(`Started: ${result.action.status}.`);
      await refresh();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, pendingIncomePreview, incomeLocationInput, incomeSkillInput, refresh, coachEvent]);

  const updateIncomeAction = useCallback(
    async (actionId: string, nextStatus: IncomeAction["status"], payout?: number) => {
      try {
        await apiRequest(apiBase, token, `/api/v1/income-engine/actions/${actionId}/status`, "POST", {
          status: nextStatus,
          actual_payout: payout,
        });
        if (nextStatus === "completed") {
          await coachEvent("action_completed", { title: "Income action completed" });
        }
        setStatus(`Income action updated to ${nextStatus}.`);
        await refresh();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, refresh, coachEvent]
  );

  const draftProposal = useCallback(
    async (actionId: string) => {
      try {
        await apiRequest(apiBase, token, `/api/v1/income-engine/actions/${actionId}/draft-proposal`, "POST");
        setStatus("Proposal draft generated.");
        await refresh();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, refresh]
  );

  const scheduleFollowup = useCallback(
    async (actionId: string) => {
      try {
        await apiRequest(apiBase, token, `/api/v1/income-engine/actions/${actionId}/schedule-followup`, "POST", {
          hours_until_followup: 24,
        });
        setStatus("Follow-up scheduled in 24h.");
        await refresh();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, refresh]
  );

  const completeLesson = useCallback(
    async (lessonId: string) => {
      try {
        await apiRequest(apiBase, token, "/api/v1/income-engine/skills/lessons/complete", "POST", { lesson_id: lessonId });
        await coachEvent("lesson_completed", { title: "Skill lesson completed" });
        setStatus("Lesson completed. Skill profile updated.");
        await refresh();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, refresh, coachEvent]
  );

  const runLoopAction = useCallback(
    async (actionType: string, refId: string) => {
      try {
        if (actionType === "open_applications") {
          router.push("/application-builder");
          return;
        }
        if (actionType === "optimize_focus" && refId) {
          setIncomeSkillInput((prev) => {
            const existing = prev
              .split(",")
              .map((x) => x.trim().toLowerCase())
              .filter(Boolean);
            if (existing.includes(refId.toLowerCase())) return prev;
            return [...existing, refId.toLowerCase()].join(", ");
          });
          setStatus(`Optimization focus set to ${refId}. Save profile to apply.`);
          return;
        }
        await apiRequest(apiBase, token, "/api/v1/income-engine/unified-loop/advance", "POST", {
          action_type: actionType,
          ref_id: refId,
          confirm: actionType === "start_opportunity",
        });
        await coachEvent("run_next_action", { title: actionType.replace(/_/g, " ") });
        setStatus(`Loop action executed: ${actionType}`);
        await refresh();
      } catch (error) {
        setStatus(String(error));
      }
    },
    [apiBase, token, refresh, coachEvent]
  );

  React.useEffect(() => {
    refresh();
  }, [refresh]);

  React.useEffect(() => {
    coachEvent("open_wallet", { title: "Opened wallet" });
  }, [coachEvent]);

  const pay = useCallback(async () => {
    if (!receiverId || !amount) return;
    try {
      const intent = await apiRequest<{ id: string }>(apiBase, token, "/api/v1/payments/create-intent", "POST", {
        receiver_id: receiverId,
        amount: Number(amount),
        currency: "USD",
      });
      await apiRequest(apiBase, token, "/api/v1/payments/confirm", "POST", { payment_intent_id: intent.id });
      setStatus("Payment confirmed.");
      setPaySuccess(`Sent $${amount} to ${receiverId}`);
      Animated.sequence([
        Animated.timing(payAnim, { toValue: 1, duration: 180, useNativeDriver: true }),
        Animated.timing(payAnim, { toValue: 0, duration: 220, useNativeDriver: true }),
      ]).start();
      await refresh();
    } catch (error) {
      setStatus(String(error));
    }
  }, [apiBase, token, receiverId, amount, refresh]);

  return (
    <EnvironmentShell
      screenKey="wallet"
      title="Wallet"
      subtitle="Fiat + stablecoin actions integrated with chat, profiles, and inbox."
      leftActions={buildRailActions("left", "wallet")}
      rightActions={buildRailActions("right", "wallet")}
      bottomActions={buildRailActions("bottom", "wallet")}
    >
      <SurfaceScroll>
        <SectionCard title="Balance" subtitle={status} right={<ActionChip label="Refresh" onPress={refresh} />}>
          <View style={ui.rowWrap}>
            <StatPill label="Fiat" value={balance ? `$${balance.fiat_balance}` : "$0.00"} />
            <StatPill label="USDC" value={balance ? `${balance.usdc_balance}` : "0"} />
          </View>
        </SectionCard>

        <SectionCard title="Financial Hub" subtitle="Secure financial access with guardrails.">
          <View style={ui.rowWrap}>
            <ActionChip
              label={`${financeDashboard?.access_policy?.access_level === "observe" ? "• " : ""}Observe`}
              onPress={() => patchAccessLevel("observe")}
            />
            <ActionChip
              label={`${financeDashboard?.access_policy?.access_level === "assist" ? "• " : ""}Assist`}
              onPress={() => patchAccessLevel("assist")}
            />
            <ActionChip
              label={`${financeDashboard?.access_policy?.access_level === "auto" ? "• " : ""}Auto`}
              onPress={() => patchAccessLevel("auto")}
            />
          </View>
          <View style={ui.rowWrap}>
            <StatPill label="Linked Accounts" value={String(financeDashboard?.linked_accounts?.length || 0)} />
            <StatPill label="Opportunities" value={String(financeDashboard?.opportunities?.length || 0)} />
            <StatPill label="Automations" value={String(financeDashboard?.automation_rules?.length || 0)} />
            <StatPill label="Audit Events" value={String(auditCount)} />
          </View>
          <View style={ui.rowWrap}>
            <ActionChip label="Run Read-only Analysis" onPress={runAnalysis} />
            <ActionChip label={biometricApprove ? "Biometric: On" : "Biometric: Off"} onPress={() => setBiometricApprove((v) => !v)} />
          </View>
          {financeAnalysis ? (
            <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>
                Spend 30d: ${financeAnalysis.cash_flow.spend_30d} ({financeAnalysis.cash_flow.trend_percent}% vs prev)
              </Text>
              {financeAnalysis.opportunities.slice(0, 3).map((opp) => (
                <Text key={opp.type} style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                  {opp.title} · Impact ${opp.impact_amount}
                </Text>
              ))}
            </View>
          ) : null}
        </SectionCard>

        <SectionCard title="Income Engine" subtitle="Daily target progress + personalized, verified opportunities.">
          <View style={ui.rowWrap}>
            <StatPill label="Today" value={`$${incomeDashboard?.targets.earnings_today?.toFixed(2) || "0.00"}`} />
            <StatPill label="Daily Target" value={`$${incomeDashboard?.targets.daily_target?.toFixed(0) || "300"}`} />
            <StatPill label="Month" value={`$${incomeDashboard?.targets.earnings_month?.toFixed(2) || "0.00"}`} />
            <StatPill label="Monthly Goal" value={`$${incomeDashboard?.targets.monthly_target?.toFixed(0) || "10000"}`} />
          </View>
          <View style={{ gap: 8 }}>
            <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>
              Daily progress: {Math.round((incomeDashboard?.targets.daily_progress || 0) * 100)}%
            </Text>
            <View style={{ height: 8, borderRadius: 999, backgroundColor: browserTheme.panelElevated, overflow: "hidden" }}>
              <View
                style={{
                  width: `${Math.min(100, Math.max(0, (incomeDashboard?.targets.daily_progress || 0) * 100))}%`,
                  height: 8,
                  backgroundColor: browserTheme.action,
                }}
              />
            </View>
            <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>
              Monthly progress: {Math.round((incomeDashboard?.targets.monthly_progress || 0) * 100)}%
            </Text>
            <View style={{ height: 8, borderRadius: 999, backgroundColor: browserTheme.panelElevated, overflow: "hidden" }}>
              <View
                style={{
                  width: `${Math.min(100, Math.max(0, (incomeDashboard?.targets.monthly_progress || 0) * 100))}%`,
                  height: 8,
                  backgroundColor: "rgba(47,210,132,0.8)",
                }}
              />
            </View>
          </View>
          <View style={{ gap: 8 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Personalization</Text>
            <TextInput
              value={dailyTargetInput}
              onChangeText={setDailyTargetInput}
              keyboardType="decimal-pad"
              placeholder="Daily target"
              placeholderTextColor={browserTheme.textMuted}
              style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
            />
            <TextInput
              value={incomeSkillInput}
              onChangeText={setIncomeSkillInput}
              placeholder="Skills (comma-separated)"
              placeholderTextColor={browserTheme.textMuted}
              style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
            />
            <TextInput
              value={incomeLocationInput}
              onChangeText={setIncomeLocationInput}
              placeholder="Location (optional)"
              placeholderTextColor={browserTheme.textMuted}
              style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
            />
            <View style={ui.rowWrap}>
              <ActionChip label="Save Profile" onPress={saveIncomeProfile} />
              <ActionChip label={`${incomeCategory === "all" ? "• " : ""}All`} onPress={() => setIncomeCategory("all")} />
              <ActionChip label={`${incomeCategory === "task" ? "• " : ""}Tasks`} onPress={() => setIncomeCategory("task")} />
              <ActionChip label={`${incomeCategory === "freelance" ? "• " : ""}Freelance`} onPress={() => setIncomeCategory("freelance")} />
              <ActionChip label={`${incomeCategory === "gig" ? "• " : ""}Gigs`} onPress={() => setIncomeCategory("gig")} />
              <ActionChip label={`${incomeCategory === "monetization" ? "• " : ""}Monetize`} onPress={() => setIncomeCategory("monetization")} />
            </View>
          </View>
          {incomeDashboard?.purchase_intelligence ? (
            <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Purchase Intelligence</Text>
              <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>{incomeDashboard.purchase_intelligence.note}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                Avg daily spend ${incomeDashboard.purchase_intelligence.avg_daily_spend} · Projected month ${incomeDashboard.purchase_intelligence.projected_month_spend}
              </Text>
            </View>
          ) : null}
          {incomeDashboard?.credit_optimization ? (
            <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Credit Optimization</Text>
              <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>
                Utilization estimate: {incomeDashboard.credit_optimization.utilization_estimate_percent}%
              </Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>{incomeDashboard.credit_optimization.recommendation}</Text>
            </View>
          ) : null}
          {optimizeHints.length ? (
            <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Auto-Optimization</Text>
              {optimizeHints.slice(0, 4).map((hint, index) => (
                <Text key={`${hint.type}-${index}`} style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                  {hint.skill ? `${hint.skill}: ` : ""}{hint.reason}
                </Text>
              ))}
            </View>
          ) : null}
        </SectionCard>

        <SectionCard title="Unified Loop" subtitle="Skills → Income → Financial → Applications → Skills">
          <View style={ui.rowWrap}>
            <StatPill label="Loop Score" value={`${Math.round((unifiedLoop?.overall_score || 0) * 100)}%`} />
            <StatPill label="Daily Remaining" value={`$${(unifiedLoop?.daily_remaining || 0).toFixed(2)}`} />
            <StatPill label="Cashflow Trend" value={`${(unifiedLoop?.metrics.cashflow_trend_percent || 0).toFixed(1)}%`} />
            <StatPill label="App Completion" value={`${Math.round((unifiedLoop?.metrics.application_completion_rate || 0) * 100)}%`} />
            <StatPill label="Streak" value={`${unifiedLoop?.habit?.streak_count || 0}d`} />
            <StatPill label="Level" value={`L${unifiedLoop?.habit?.level || 1}`} />
          </View>
          {typeof unifiedLoop?.habit?.progress_percent === "number" ? (
            <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Daily Progress Bar</Text>
              <View style={{ height: 8, borderRadius: 999, backgroundColor: "rgba(255,255,255,0.08)", overflow: "hidden" }}>
                <View style={{ width: `${Math.max(3, Math.min(100, unifiedLoop.habit.progress_percent))}%`, height: 8, backgroundColor: browserTheme.action }} />
              </View>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                {Math.round(unifiedLoop.habit.progress_percent)}% complete · Active stage: {unifiedLoop?.active_stage || "skills"}
              </Text>
            </View>
          ) : null}
          {unifiedLoop?.stages?.map((stage) => (
            <View key={stage.key} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{stage.label}</Text>
              <View style={{ height: 6, borderRadius: 999, backgroundColor: "rgba(255,255,255,0.08)", overflow: "hidden" }}>
                <View style={{ width: `${Math.max(4, Math.min(100, stage.score * 100))}%`, height: 6, backgroundColor: browserTheme.action }} />
              </View>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>Readiness {Math.round(stage.score * 100)}%</Text>
            </View>
          ))}
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 6 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Next Best Action</Text>
            {activeGuidance?.dominant_action ? (
              <View style={{ gap: 5 }}>
                <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>
                  {activeGuidance.dominant_action.title}
                  {activeGuidance.dominant_action.subtitle ? ` · ${activeGuidance.dominant_action.subtitle}` : ""}
                </Text>
                <View style={ui.rowWrap}>
                  <ActionChip label="Run Dominant Action" onPress={() => runLoopAction(activeGuidance.dominant_action!.action_type, activeGuidance.dominant_action!.ref_id)} />
                </View>
              </View>
            ) : null}
            {unifiedLoop?.next_actions?.slice(0, 4).map((action, idx) => (
              <View key={`${action.action_type}-${idx}`} style={{ gap: 5 }}>
                <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>
                  {action.title}
                  {action.subtitle ? ` · ${action.subtitle}` : ""}
                </Text>
                <View style={ui.rowWrap}>
                  <ActionChip label="Run" onPress={() => runLoopAction(action.action_type, action.ref_id)} />
                </View>
              </View>
            ))}
          </View>
          {unifiedLoop?.habit?.micro_rewards?.length ? (
            <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Micro Rewards</Text>
              {unifiedLoop.habit.micro_rewards.slice(0, 3).map((reward, idx) => (
                <Text key={`${reward.event_type}-${idx}`} style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                  +{reward.xp} xp · {reward.title}
                </Text>
              ))}
            </View>
          ) : null}
        </SectionCard>

        <SectionCard title="Daily AI Coach" subtitle="Supportive, adaptive guidance for money, skills, and consistency.">
          <View style={ui.rowWrap}>
            <StatPill label="Goal" value={`$${morningBrief?.brief.daily_goal?.toFixed(0) || "300"}`} />
            <StatPill label="Progress" value={`${Math.round((morningBrief?.brief.progress_today || 0) * 100)}%`} />
            <StatPill label="Streak" value={`${morningBrief?.streak_count || 0}d`} />
            <StatPill label="Tone" value={coachToneMode} />
            <StatPill label="Adaptive" value={morningBrief?.tone?.adaptive_tone || coachToneMode} />
          </View>
          <View style={ui.rowWrap}>
            <ActionChip label={`${coachToneMode === "supportive" ? "• " : ""}Supportive`} onPress={() => setCoachTone("supportive")} />
            <ActionChip label={`${coachToneMode === "direct" ? "• " : ""}Direct`} onPress={() => setCoachTone("direct")} />
            <ActionChip label={`${coachToneMode === "aggressive" ? "• " : ""}Aggressive`} onPress={() => setCoachTone("aggressive")} />
          </View>
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Morning Brief</Text>
            {(morningBrief?.brief.simple_plan || []).slice(0, 3).map((line, idx) => (
              <Text key={`${line}-${idx}`} style={{ color: browserTheme.textMuted, fontSize: 12 }}>{line}</Text>
            ))}
            {(morningBrief?.brief.alerts || []).slice(0, 2).map((line, idx) => (
              <Text key={`${line}-${idx}`} style={{ color: "#ffb48a", fontSize: 12 }}>{line}</Text>
            ))}
          </View>
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Active Guidance</Text>
            {(activeGuidance?.prompts || []).slice(0, 3).map((prompt, idx) => (
              <View key={`${prompt.action_type}-${idx}`} style={{ gap: 4 }}>
                <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>{prompt.label}</Text>
                <View style={ui.rowWrap}>
                  <ActionChip label="Do This" onPress={() => runLoopAction(prompt.action_type, prompt.ref_id)} />
                </View>
              </View>
            ))}
            {(activeGuidance?.decision_support || []).slice(0, 1).map((item, idx) => (
              <Text key={`${item.title}-${idx}`} style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                {item.title}: {item.detail}
              </Text>
            ))}
          </View>
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>End of Day Review</Text>
            {(endReview?.wins || []).slice(0, 3).map((win, idx) => (
              <Text key={`${win}-${idx}`} style={{ color: browserTheme.textMuted, fontSize: 12 }}>{win}</Text>
            ))}
            {(endReview?.next_steps || []).slice(0, 2).map((step, idx) => (
              <Text key={`${step}-${idx}`} style={{ color: browserTheme.textSoft, fontSize: 12 }}>Next: {step}</Text>
            ))}
          </View>
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Weekly Coach</Text>
            <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>
              ${weeklyCoach?.weekly_earnings?.toFixed(2) || "0.00"} earned · {weeklyCoach?.completed_actions || 0} actions · trend {weeklyCoach?.trend || "stable"}
            </Text>
            {(weeklyCoach?.strategy || []).slice(0, 2).map((s, idx) => (
              <Text key={`${s}-${idx}`} style={{ color: browserTheme.textMuted, fontSize: 12 }}>{s}</Text>
            ))}
          </View>
        </SectionCard>

        <SectionCard title="Skills Engine" subtitle="Dynamic skill profile connected directly to earning outcomes.">
          <View style={ui.rowWrap}>
            <StatPill label="Level" value={incomeDashboard?.skills_engine.progression.current_level || "starter"} />
            <StatPill label="Next" value={incomeDashboard?.skills_engine.progression.next_level || "builder"} />
            <StatPill label="To Next" value={`$${incomeDashboard?.skills_engine.progression.remaining_to_next?.toFixed(0) || "0"}`} />
          </View>
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Earning Path Builder</Text>
            <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>
              {incomeDashboard?.skills_engine.earning_path.summary || "No path available yet."}
            </Text>
            {incomeDashboard?.skills_engine.earning_path.steps?.slice(0, 4).map((step) => (
              <Text key={step.opportunity_id} style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                {step.title} · ${step.expected_payout} · {step.estimated_minutes}m
              </Text>
            ))}
          </View>
          {incomeDashboard?.skills_engine.skills?.slice(0, 6).map((skill) => (
            <View key={skill.skill} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>
                {skill.skill} · L{skill.level}
              </Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                Proficiency {Math.round(skill.proficiency * 100)}% · Earnings ${skill.earnings_generated.toFixed(2)}
              </Text>
              <View style={{ height: 6, borderRadius: 999, backgroundColor: "rgba(255,255,255,0.08)", overflow: "hidden" }}>
                <View style={{ width: `${Math.max(4, Math.min(100, skill.proficiency * 100))}%`, height: 6, backgroundColor: browserTheme.action }} />
              </View>
            </View>
          ))}
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 5 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Skill → Money Mapping</Text>
            {incomeDashboard?.skills_engine.skill_to_money_mapping?.slice(0, 5).map((map) => (
              <Text key={map.skill} style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                {map.skill}: {map.opportunity_count} matches · avg ${map.avg_payout} · cats {map.top_categories.join(", ")}
              </Text>
            ))}
          </View>
          <View style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 5 }}>
            <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Skill Upgrade Engine</Text>
            {incomeDashboard?.skills_engine.upgrades?.slice(0, 5).map((lesson) => (
              <View key={lesson.lesson_id} style={{ gap: 3 }}>
                <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>
                  {lesson.title} · {lesson.skill} · {lesson.duration_minutes}m · impact +{Math.round(lesson.earning_impact * 100)}%
                </Text>
                <View style={ui.rowWrap}>
                  <ActionChip label="Complete Lesson" onPress={() => completeLesson(lesson.lesson_id)} />
                </View>
              </View>
            ))}
          </View>
        </SectionCard>

        <SectionCard title="Income Opportunities" subtitle="Tap → autofill → confirm → start. No guaranteed income claims.">
          {incomeOpportunities.slice(0, 10).map((opp) => (
            <View key={opp.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 5 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{opp.title}</Text>
              <Text style={ui.bodyText}>{opp.description}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                {opp.category} · ${opp.payout_min}–${opp.payout_max} · {opp.estimated_minutes}m · Match {Math.round(opp.match_score * 100)}%
              </Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                {opp.verified ? "Verified listing" : "Unverified"} · Scam risk: {opp.scam_risk_level}
              </Text>
              <View style={ui.rowWrap}>
                <ActionChip label={pendingOpportunityId === opp.id ? "Preparing..." : "Preview Start"} onPress={() => previewIncomeStart(opp.id)} />
              </View>
            </View>
          ))}
          {pendingIncomePreview ? (
            <View style={{ borderRadius: 12, padding: 10, backgroundColor: "rgba(14,28,46,0.95)", borderWidth: 1, borderColor: browserTheme.border, gap: 6 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>Confirm Opportunity Start</Text>
              <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>{pendingIncomePreview.title}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                Est. payout ${pendingIncomePreview.estimated_payout_range[0]}–${pendingIncomePreview.estimated_payout_range[1]} · {pendingIncomePreview.estimated_minutes}m
              </Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                Autofill fields: {pendingIncomePreview.autofill_fields.join(", ") || "none"}
              </Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Confirm + Start" onPress={confirmIncomeStart} />
                <ActionChip label="Cancel" onPress={() => setPendingIncomePreview(null)} />
              </View>
            </View>
          ) : null}
        </SectionCard>

        <SectionCard title="Income Actions" subtitle="Automation support for drafting proposals and follow-ups.">
          {incomeActions.slice(0, 10).map((action) => (
            <View key={action.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 5 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>
                Action {action.status} · Est ${action.expected_payout}
              </Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                Autofill: {action.autofill_used ? "Yes" : "No"} · Proposal: {action.proposal_drafted ? "Done" : "No"} · Follow-up: {action.followup_scheduled ? "Set" : "No"}
              </Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Mark Applied" onPress={() => updateIncomeAction(action.id, "applied")} />
                <ActionChip label="Mark Complete" onPress={() => updateIncomeAction(action.id, "completed", action.expected_payout)} />
                <ActionChip label="Draft Proposal" onPress={() => draftProposal(action.id)} />
                <ActionChip label="Schedule Follow-up" onPress={() => scheduleFollowup(action.id)} />
              </View>
            </View>
          ))}
        </SectionCard>

        <SectionCard title="Send Payment" subtitle="Username-based transfer flow">
          <TextInput
            value={receiverId}
            onChangeText={(value) => {
              setReceiverId(value);
              setActiveConversationUserId(value);
            }}
            placeholder="Receiver user id"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <TextInput
            value={amount}
            onChangeText={setAmount}
            keyboardType="decimal-pad"
            placeholder="Amount"
            placeholderTextColor={browserTheme.textMuted}
            style={{ borderRadius: 12, borderWidth: 1, borderColor: browserTheme.border, color: browserTheme.text, padding: 10 }}
          />
          <View style={ui.rowWrap}>
            <ActionChip label="Request" />
            <ActionChip label="Split Bill" />
            <ActionChip label="Invoice" />
          </View>
          <Animated.View style={{ transform: [{ scale: payAnim.interpolate({ inputRange: [0, 1], outputRange: [1, 1.04] }) }] }}>
            <Pressable onPress={pay} style={{ borderRadius: 12, paddingVertical: 10, alignItems: "center", backgroundColor: browserTheme.action }}>
              <Text style={{ color: "#03101E", fontWeight: "700" }}>Confirm Payment</Text>
            </Pressable>
          </Animated.View>
          {paySuccess ? (
            <Animated.View
              style={{
                borderRadius: 12,
                borderWidth: 1,
                borderColor: "rgba(47,210,132,0.35)",
                backgroundColor: "rgba(47,210,132,0.12)",
                padding: 10,
                opacity: payAnim.interpolate({ inputRange: [0, 1], outputRange: [0.8, 1] }),
              }}
            >
              <Text style={{ color: browserTheme.textSoft, fontSize: 12 }}>{paySuccess}</Text>
            </Animated.View>
          ) : null}
        </SectionCard>

        <SectionCard title="Action Preview + Approval" subtitle="Approve, edit, or decline before any money movement.">
          <View style={ui.rowWrap}>
            <ActionChip label="Preview Savings Move" onPress={previewSavingsMove} />
            <ActionChip label="Preview Trade" onPress={previewTrade} />
          </View>
          {previews.slice(0, 6).map((preview) => (
            <View key={preview.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 5 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>
                {preview.action_type} · {preview.status}
              </Text>
              <Text style={ui.bodyText}>{preview.reason}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                Amount: ${preview.payload?.amount || 0} · Hard confirm: {preview.requires_hard_confirmation ? "Yes" : "No"} · First-time: {preview.first_time_action ? "Yes" : "No"}
              </Text>
              {preview.guardrails?.blocked ? (
                <Text style={{ color: "#ff9f9f", fontSize: 12 }}>
                  Blocked by guardrails: {(preview.guardrails?.blocked_reasons || []).join(", ")}
                </Text>
              ) : null}
              <View style={ui.rowWrap}>
                <ActionChip label="Approve" onPress={() => approvePreview(preview.id, "standard")} />
                {preview.action_type === "trade" ? <ActionChip label="One-click Trade" onPress={() => approvePreview(preview.id, "one_click")} /> : null}
                <ActionChip label="Decline" onPress={() => declinePreview(preview.id)} />
              </View>
            </View>
          ))}
        </SectionCard>

        <SectionCard title="Money Automation" subtitle="Narrow rule-based automation with guardrails and approval controls.">
          <View style={ui.rowWrap}>
            <ActionChip label="After Payday Transfer" onPress={() => createAutomation("fixed_after_payday")} />
            <ActionChip label="Round-up Savings" onPress={() => createAutomation("round_up")} />
            <ActionChip label="Unusual Charge Alert" onPress={() => createAutomation("unusual_charge_alert")} />
            <ActionChip label="Bill Reminder" onPress={() => createAutomation("recurring_bill_reminder")} />
          </View>
          {financeDashboard?.automation_rules?.slice(0, 8).map((rule) => (
            <View key={rule.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated, gap: 4 }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>
                {rule.name} · {rule.enabled ? "Enabled" : "Disabled"}
              </Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>
                Type: {rule.rule_type} · Approval required: {rule.require_approval ? "Yes" : "No"}
              </Text>
              <View style={ui.rowWrap}>
                <ActionChip label="Run Rule" onPress={() => runAutomation(rule.id)} />
              </View>
            </View>
          ))}
        </SectionCard>

        <SectionCard title="Transactions" subtitle="Recent payment intents">
          {history.slice(0, 12).map((item) => (
            <View key={item.id} style={{ borderRadius: 12, padding: 10, backgroundColor: browserTheme.panelElevated }}>
              <Text style={{ color: browserTheme.text, fontWeight: "700" }}>{item.amount} {item.currency}</Text>
              <Text style={ui.bodyText}>{item.status}</Text>
              <Text style={{ color: browserTheme.textMuted, fontSize: 12 }}>{item.created_at}</Text>
            </View>
          ))}
        </SectionCard>
      </SurfaceScroll>
    </EnvironmentShell>
  );
}
