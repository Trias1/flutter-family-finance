// A thin bar at the top while a route loads; pages render their own skeletons.
export default function LocaleLoading() {
  return (
    <div className="min-h-screen" style={{ backgroundColor: "var(--bg)" }} aria-busy="true">
      <div className="route-progress" />
    </div>
  )
}
