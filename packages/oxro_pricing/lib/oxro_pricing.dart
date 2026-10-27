/// OXRO pricing engine — commission, platform fee, delivery payout.
///
/// This package is the reference implementation of the OXRO money rules.
/// The customer app, seller portal, rider app, admin panel and the future
/// backend must all produce the same numbers. Golden vectors in
/// `golden_vectors.json` are the shared contract.
library;

export 'src/money.dart';
export 'src/pricing_config.dart';
export 'src/pricing_engine.dart';
