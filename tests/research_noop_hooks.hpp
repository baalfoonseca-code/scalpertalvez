// Legacy HOST fixtures intentionally test operational bodies in isolation.
// Terminal observer boundary is a void no-op here; research ON/OFF integration
// fixtures use the real modules instead. This is never included in the EA.
#ifndef REMORA_RESEARCH_NOOP_HOST
#define REMORA_RESEARCH_NOOP_HOST
#define RESEARCH_NOOP(name) template<class... T>void name(const T&...){}
RESEARCH_NOOP(BookResearchArchiveOperationalWindow)
RESEARCH_NOOP(BookResearchOperationalEvidence)
RESEARCH_NOOP(BookResearchOperationalUnavailable)
RESEARCH_NOOP(BookResearchCaptureTrade)
RESEARCH_NOOP(BookResearchObserveMatrix)
RESEARCH_NOOP(BookResearchCaptureCandidate)
RESEARCH_NOOP(BookResearchCaptureArmed)
RESEARCH_NOOP(BookResearchRegionInvalid)
RESEARCH_NOOP(BookResearchAfterSend)
RESEARCH_NOOP(BookResearchRecordDispatch)
RESEARCH_NOOP(BookResearchBorrowedTicks)
#undef RESEARCH_NOOP
#endif
