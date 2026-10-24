"use client"

import { useEffect, useState } from "react"

/** Step list for the guide; highlights the step currently on screen. */
export default function GuideToc({ title, items }: { title: string; items: { id: string; label: string }[] }) {
  const [active, setActive] = useState(items[0]?.id ?? "")

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)
        if (visible[0]) setActive(visible[0].target.id)
      },
      { rootMargin: "-80px 0px -60% 0px" },
    )
    for (const item of items) {
      const el = document.getElementById(item.id)
      if (el) observer.observe(el)
    }
    return () => observer.disconnect()
  }, [items])

  return (
    <nav aria-label={title}>
      <p className="text-xs font-semibold uppercase tracking-[0.14em]" style={{ color: "var(--text-muted)" }}>{title}</p>
      <ol className="mt-4 space-y-0.5 border-l" style={{ borderColor: "var(--border)" }}>
        {items.map((item, i) => {
          const isActive = item.id === active
          return (
            <li key={item.id}>
              <a
                href={`#${item.id}`}
                aria-current={isActive ? "step" : undefined}
                className="-ml-px flex gap-3 border-l-2 py-1.5 pl-4 text-sm"
                style={{
                  borderColor: isActive ? "var(--primary)" : "transparent",
                  color: isActive ? "var(--text-primary)" : "var(--text-secondary)",
                  fontWeight: isActive ? 600 : 400,
                }}
              >
                <span className="w-5 shrink-0 tabular-nums" style={{ color: "var(--text-muted)" }}>{String(i + 1).padStart(2, "0")}</span>
                {item.label}
              </a>
            </li>
          )
        })}
      </ol>
    </nav>
  )
}
