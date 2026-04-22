import { FeedbackSignal, LearningInput } from "./learning-types";

export function deriveFeedback(input: LearningInput): FeedbackSignal {
  const success = input.result.ok;
  const failure = !input.result.ok;
  const abandonment = /cancel/i.test(input.result.subtitle || "") || input.result.status === "confirm_required";
  const correction = input.previousActionStatus === "error" && success;
  return { success, failure, correction, abandonment };
}
