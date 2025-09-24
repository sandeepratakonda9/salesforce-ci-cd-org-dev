// This class intentionally contains PMD suppression markers for pipeline testing.
public with sharing class BadSuppressionExample {

    // 1) @SuppressWarnings — should be flagged
    @SuppressWarnings('PMD')
    public static void doStuff(String name) {
        // 2) NOPMD — should be flagged
        Integer x = 42; // NOPMD - AvoidUnusedPrivateFields (example)

        // 3) Inline // PMD — should be flagged
        if (String.isEmpty(name)) { // PMD: AvoidDeeplyNestedIfStmts (example text)
            name = 'fallback';
        }

        // 4) NOSONAR — should be flagged by our pattern even though it's a Sonar tag
        Integer y = x + 1; // NOSONAR - example suppression

        // An empty catch to look like a PMD rule target (the suppression is above, not here)
        try {
            Integer z = 1 / 0;
        } catch (Exception e) {
            // Intentionally empty (no PMD tag here)
        }
    }

    // Another method with a different @SuppressWarnings pattern
    @SuppressWarnings
    public static Integer calc(Integer a, Integer b) {
        // PMD inline again
        return (a == null ? 0 : a) + (b == null ? 0 : b); // PMD
    }
}
