# Telemetry [![Build Status](https://travis-ci.org/yammer/telemetry-ruby.png)](https://travis-ci.org/yammer/telemetry-ruby)

Make your app talk…and talk…and talk. Inspired by Google's [Dapper](http://research.google.com/pubs/pub36356.html).

Here is a sample trace view generated by the
[TracingBundle](telemetry-dropwizard/src/main/java/com/yammer/telemetry/dropwizard/TracingBundle.java) of the
execution of the [TracedResource](telemetry-example/src/main/java/com/yammer/telemetry/example/resources/TracedResource.java) in the telemetry-example application.

![Sample Span](/telemetry-service/screenshot.png "Sample Span View")

## IDs

Trace and span IDs will be expressed as 64-bit longs.

## Trace/Span Passing

In order to trace across hosts trace ID and span ID information must be passed from one host to the next.

### Over HTTP

Clients will pass the current trace ID and the current span ID to downstream services via HTTP request headers:

    X-Telemetry-TraceId: {current trace ID}
    X-Telemetry-SpanId: {current span ID}
    X-Telemetry-Parent-SpanId: {parent span ID, may be absent if this is the root span}

## Notes

### [Phylogenetic Trees](https://en.wikipedia.org/wiki/Phylogenetic_tree)

May be an interesting, high-density way of viewing trace data.

   * [phyloXML](https://en.wikipedia.org/wiki/PhyloXML) - expressive XML format for phylogenetic trees
   * [jsPhyloSVG](http://www.jsphylosvg.com/) - JavaScript library for rendering phylogenetic trees from phyloXML (and some other formats).

### Network Diagrams

JavaScript libraries for rendering network (dependency?) diagrams.

   * [arbor.js](http://arborjs.org/)
   * [sigma.js](http://sigmajs.org/)

### Visualization

More random (not D3) JavaScript visualization libraries to check out.

   * [JavaScript InfoVis Toolkit](http://philogb.github.io/jit/)
   * [D3](http://d3js.org/) - okay, fine…D3, too.