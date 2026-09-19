import 'package:cloud_functions/cloud_functions.dart';

/// Cloud Functions are deployed to Sydney (see setGlobalOptions in
/// functions/index.js), next to the Firestore database — Firestore-triggered
/// functions have to share the database's region. The client defaults to
/// us-central1, so every callable must go through [appFunctions] or it
/// fails with "not found".
const functionsRegion = 'australia-southeast1';

FirebaseFunctions get appFunctions => FirebaseFunctions.instanceFor(region: functionsRegion);
