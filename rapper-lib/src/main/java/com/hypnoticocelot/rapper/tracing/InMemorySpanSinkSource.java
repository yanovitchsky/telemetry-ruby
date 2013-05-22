package com.hypnoticocelot.rapper.tracing;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

public class InMemorySpanSinkSource implements SpanSink, SpanSource {
    private final ConcurrentMap<UUID, Trace> traces;

    public InMemorySpanSinkSource() {
        traces = new ConcurrentHashMap<>();
    }

    @Override
    public Collection<Trace> getTraces() {
        return traces.values();
    }

    @Override
    public Trace getTrace(UUID traceId) {
        return traces.get(traceId);
    }

    @Override
    public void record(Span span) {
        // This is cleaner from a code perspective, but it means we allocate a new Trace on
        // every request even if one is already in the map. This may be worth changing if
        // performance suffers here due to the frequency of calls.
        final Trace trace = traces.putIfAbsent(span.getTraceId(), Trace.startTrace(span));
        if (trace != null) {
            trace.addSpan(span);
        }
    }
}
