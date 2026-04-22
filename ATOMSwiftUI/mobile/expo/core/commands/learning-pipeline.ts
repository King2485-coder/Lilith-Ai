import { applyBehaviorLearning } from "./behavior-model";
import { deriveFeedback } from "./feedback-engine";
import { scoreFeedback } from "./scoring-engine";
import { LearningInput } from "./learning-types";
import { UserMemoryProfile } from "./memory-types";

export function runLearningPipelineAsync({
  memory,
  input,
  onComplete,
}: {
  memory: UserMemoryProfile;
  input: LearningInput;
  onComplete: (next: UserMemoryProfile) => void;
}) {
  setTimeout(() => {
    const feedback = deriveFeedback(input);
    const score = scoreFeedback(feedback);
    const next = applyBehaviorLearning(memory, input, score);
    onComplete(next);
  }, 0);
}
