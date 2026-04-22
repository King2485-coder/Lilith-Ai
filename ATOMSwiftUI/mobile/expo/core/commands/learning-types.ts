import { CommandExecutionResult, CommandPlan, CommandSuggestion } from "./types";

export type FeedbackSignal = {
  success: boolean;
  failure: boolean;
  correction: boolean;
  abandonment: boolean;
};

export type LearningScore = {
  total: number;
  positive: number;
  negative: number;
};

export type LearningInput = {
  command: string;
  plan: CommandPlan;
  result: CommandExecutionResult;
  suggestionsShown: CommandSuggestion[];
  usedSuggestion?: CommandSuggestion;
  previousActionStatus?: "success" | "error" | "blocked";
};
