"use client"

import { useTranslations } from "next-intl"

import { ErrorState } from "@/components/ui"
import { useFamilyData, type CollectionKey } from "@/lib/family-data"

/** True when any of `keys` failed to load, so a page can show DataError instead of an empty state. */
export function useFailed(...keys: CollectionKey[]) {
  const { failed } = useFamilyData()
  return keys.some((k) => failed.includes(k))
}

/** Inline load error with a retry that re-subscribes to every collection. */
export default function DataError() {
  const t = useTranslations("dash.errors")
  const { retry } = useFamilyData()
  return <ErrorState title={t("loadFailed")} hint={t("loadFailedHint")} retryLabel={t("retry")} onRetry={retry} />
}
