import { FeedbackSignal, LearningScore } from "./learning-types";

export function scoreFeedback(feedback: FeedbackSignal): LearningScore {
  let total = 0;
  let positive = 0;
  let negative = 0;
  if (feedback.success) {
    total += 2;
    positive += 2;
  }
  if (feedback.failure) {
    total -= 2;
    negative += 2;
  }
  if (feedback.correction) {
    total += 1;
    positive += 1;
  }
  if (feedback.abandonment) {
    total -= 1;
    negative += 1;
  }
  return { total, positive, negative };
}
