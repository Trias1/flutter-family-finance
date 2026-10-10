import { Skeleton } from "@/components/ui"

export default function DashboardLoading() {
  return (
    <div className="space-y-6">
      <Skeleton className="h-7 w-40" />
      <Skeleton className="h-24 w-full" />
      <Skeleton className="h-64 w-full" />
    </div>
  )
}
