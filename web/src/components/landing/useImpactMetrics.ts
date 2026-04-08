import { useQuery } from "@tanstack/react-query";

import { apiGetJson } from "@/lib/api";

export type PublicMetricDto = {
  displayValue: string;
};

const staleTime = 5 * 60 * 1000;

export function useGirlsServedMetric() {
  return useQuery({
    queryKey: ["public-impact", "girls-served"],
    queryFn: () => apiGetJson<PublicMetricDto>("/api/public/impact/girls-served"),
    staleTime,
  });
}

export function useSafehousesMetric() {
  return useQuery({
    queryKey: ["public-impact", "safehouses"],
    queryFn: () => apiGetJson<PublicMetricDto>("/api/public/impact/safehouses"),
    staleTime,
  });
}

export function useReintegrationRateMetric() {
  return useQuery({
    queryKey: ["public-impact", "reintegration-rate"],
    queryFn: () => apiGetJson<PublicMetricDto>("/api/public/impact/reintegration-rate"),
    staleTime,
  });
}
