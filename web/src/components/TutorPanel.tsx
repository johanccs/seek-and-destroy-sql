import { useEffect, useRef, useState } from "react";
import ReactMarkdown from "react-markdown";
import DOMPurify from "dompurify";
import { api } from "../api";
import type { TutorMessage } from "../types";
import { FontSizeControl, useFontSize } from "./FontSizeControl";

function SafeSvg({ code }: { code: string }) {
  const clean = DOMPurify.sanitize(code, { USE_PROFILES: { svg: true, svgFilters: true } });
  return <div className="tutor-svg" dangerouslySetInnerHTML={{ __html: clean }} />;
}

// Renders assistant markdown, treating ```svg fenced blocks as sanitized inline diagrams
// instead of code text.
function TutorMarkdown({ content }: { content: string }) {
  return (
    <ReactMarkdown
      components={{
        code(props) {
          const { className, children } = props as { className?: string; children?: React.ReactNode };
          const lang = /language-(\w+)/.exec(className || "")?.[1];
          const text = String(children ?? "").replace(/\n$/, "");
          if (lang === "svg") return <SafeSvg code={text} />;
          return <code className={className}>{children}</code>;
        },
      }}
    >
      {content}
    </ReactMarkdown>
  );
}

const TUTOR_NAME = "Sarge";

function ThinkingDots() {
  return (
    <span className="tutor-thinking">
      {TUTOR_NAME} is thinking
      <span className="tutor-dots"><span>.</span><span>.</span><span>.</span></span>
    </span>
  );
}

function fmtZar(v: number | null | undefined) {
  if (v == null) return null;
  if (v < 0.01) return `R${v.toFixed(4)}`;
  return `R${v.toFixed(2)}`;
}

export function TutorPanel({ lessonId }: { lessonId: string }) {
  const [open, setOpen] = useState(false);
  const [configured, setConfigured] = useState<boolean | null>(null);
  const [messages, setMessages] = useState<TutorMessage[]>([]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const [totalCostZar, setTotalCostZar] = useState(0);
  const listRef = useRef<HTMLDivElement>(null);
  const abortRef = useRef<AbortController | null>(null);
  const tutorFs = useFontSize("tutor", 13);

  useEffect(() => {
    api.tutorStatus().then((s) => setConfigured(s.configured)).catch(() => setConfigured(false));
  }, []);

  useEffect(() => {
    setMessages([]);
    setTotalCostZar(0);
    if (!open) return;
    api.tutorHistory(lessonId).then((h) => {
      setMessages(h);
      setTotalCostZar(h.reduce((sum, m) => sum + (m.costZar ?? 0), 0));
    });
    return () => abortRef.current?.abort();
  }, [lessonId, open]);

  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight });
  }, [messages]);

  const send = async () => {
    const text = input.trim();
    if (!text || sending) return;
    setInput("");
    setSending(true);
    setMessages((m) => [...m, { role: "user", content: text, ts: Date.now() }]);
    setMessages((m) => [...m, { role: "assistant", content: "", ts: Date.now() }]);

    const controller = new AbortController();
    abortRef.current = controller;
    try {
      await api.tutorChat(
        lessonId,
        text,
        (delta) => {
          setMessages((m) => {
            const next = [...m];
            next[next.length - 1] = { ...next[next.length - 1], content: next[next.length - 1].content + delta };
            return next;
          });
        },
        (costZar) => {
          if (costZar == null) return;
          setTotalCostZar((t) => t + costZar);
          setMessages((m) => {
            const next = [...m];
            next[next.length - 1] = { ...next[next.length - 1], costZar };
            return next;
          });
        },
        controller.signal,
      );
    } catch (e) {
      setMessages((m) => {
        const next = [...m];
        next[next.length - 1] = { ...next[next.length - 1], content: `⚠️ ${String((e as Error).message ?? e)}` };
        return next;
      });
    } finally {
      setSending(false);
    }
  };

  const resetChat = async () => {
    await api.tutorReset(lessonId);
    setMessages([]);
    setTotalCostZar(0);
  };

  if (configured === false) return null;

  return (
    <div className={`tutor-panel ${open ? "open" : ""}`}>
      <div className="tutor-toggle" onClick={() => setOpen((o) => !o)}>
        🤖 {TUTOR_NAME} — AI Tutor {open ? "▾" : "▸"}
        {totalCostZar > 0 && <span className="tutor-cost-total">{fmtZar(totalCostZar)}</span>}
      </div>
      {open && (
        <div className="tutor-body">
          <div style={{ display: "flex", justifyContent: "flex-end", padding: "6px 14px 0" }}>
            <FontSizeControl label="AI Tutor" fontSize={tutorFs} />
          </div>
          <div className="tutor-messages fontsize-zoom-wrap" style={{ "--panel-zoom": tutorFs.size / 13 } as React.CSSProperties} ref={listRef}>
            {messages.length === 0 && (
              <div className="muted tutor-empty">Ask {TUTOR_NAME} about this lesson — how it works, why it happens, or what to try.</div>
            )}
            {messages.map((m, i) => (
              <div className={`tutor-msg ${m.role}`} key={i}>
                {m.content ? (
                  <TutorMarkdown content={m.content} />
                ) : sending && i === messages.length - 1 ? (
                  <ThinkingDots />
                ) : null}
                {m.costZar != null && <div className="tutor-cost">{fmtZar(m.costZar)}</div>}
              </div>
            ))}
          </div>
          <div className="tutor-input-row">
            <input
              type="text"
              placeholder="Ask the tutor…"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && send()}
              disabled={sending}
            />
            <button className="btn primary" onClick={send} disabled={sending || !input.trim()}>
              {sending ? "Thinking…" : "Send"}
            </button>
            <button className="btn ghost" onClick={resetChat} disabled={sending} title="Clear chat history">↺</button>
          </div>
        </div>
      )}
    </div>
  );
}
