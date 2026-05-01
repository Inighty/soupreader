class SelectorStepCompat {
  // '' for first, ' ' descendant, '>' child, '+' adjacent, '~' sibling
  final String combinator;
  final String selector;
  final List<NthFilter> nthFilters;

  const SelectorStepCompat({
    required this.combinator,
    required this.selector,
    required this.nthFilters,
  });
}

class NthFilter {
  // nth-child / nth-last-child / nth-of-type / nth-last-of-type
  final String kind;
  final NthExpr expr;

  const NthFilter({required this.kind, required this.expr});
}

class NthExpr {
  final int a;
  final int b;

  const NthExpr({required this.a, required this.b});
}

class NthExtractResult {
  final String baseSelector;
  final List<NthFilter> filters;

  const NthExtractResult({
    required this.baseSelector,
    required this.filters,
  });
}

class NormalizedListRule {
  final String selector;
  final bool reverse;

  const NormalizedListRule({
    required this.selector,
    required this.reverse,
  });

  @override
  String toString() => 'selector=$selector reverse=$reverse';
}
