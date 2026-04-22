import { Redirect } from "expo-router";
import { useSession } from "../providers/SessionProvider";

export default function Index() {
  const { onboardingCompleted } = useSession();
  return <Redirect href={onboardingCompleted ? "/home" : "/onboarding"} />;
}
