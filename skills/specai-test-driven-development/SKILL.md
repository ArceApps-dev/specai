---
name: specai-test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code
command: false
metadata:
  author: ArceApps SpecAI
  version: "1.0"
---

# Test-Driven Development (TDD)

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

**Violating the letter of the rules is violating the spirit of the rules.**

## When to Use

**Always:**
- New features
- Bug fixes
- Refactoring
- Behavior changes

**Exceptions (ask your human partner):**
- Throwaway prototypes
- Generated code
- Configuration files

Thinking "skip TDD just this once"? Stop. That's rationalization.

## The Iron Law (INQUEBRANTABLE)

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

**No exceptions:**
- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Don't look at it
- Delete means delete

Implement fresh from tests. Period.

**This law applies to EVERY feature, EVERY bugfix, EVERY behavior change. NO shortcuts. NO rationalizations. Skirting this = not doing specai.**

## Red-Green-Refactor

```dot
digraph tdd_cycle {
    rankdir=LR;
    red [label="RED\nWrite failing test", shape=box, style=filled, fillcolor="#ffcccc"];
    verify_red [label="Verify fails\ncorrectly", shape=diamond];
    green [label="GREEN\nMinimal code", shape=box, style=filled, fillcolor="#ccffcc"];
    verify_green [label="Verify passes\nAll green", shape=diamond];
    refactor [label="REFACTOR\nClean up", shape=box, style=filled, fillcolor="#ccccff"];
    next [label="Next", shape=ellipse];

    red -> verify_red;
    verify_red -> green [label="yes"];
    verify_red -> red [label="wrong\nfailure"];
    green -> verify_green;
    verify_green -> refactor [label="yes"];
    verify_green -> green [label="no"];
    refactor -> verify_green [label="stay\ngreen"];
    verify_green -> next;
    next -> red;
}
```

### RED - Write Failing Test

### SAFETY NET — Before Modifying Existing Files

**Only applies when modifying an existing file (not creating a new one).**

Before touching any production code that already exists:

1. Run the existing tests for that file:
   ```bash
   npm test path/to/existing.test.ts
   ```
2. Record the baseline: "{N} tests passing"
3. If any test FAILS → STOP. Report as "pre-existing failure". Do NOT fix it.
   Fixing pre-existing failures is out of scope for this task.
4. If all pass → proceed. You now have proof you won't break what already works.

Skip this step only when creating a brand-new file with no existing tests.

Write one minimal test showing what should happen.

<Good>
```typescript
test('retries failed operations 3 times', async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'success';
  };

  const result = await retryOperation(operation);

  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```
Clear name, tests real behavior, one thing
</Good>

<Bad>
```typescript
test('retry works', async () => {
  const mock = jest.fn()
    .mockRejectedValueOnce(new Error())
    .mockRejectedValueOnce(new Error())
    .mockResolvedValueOnce('success');
  await retryOperation(mock);
  expect(mock).toHaveBeenCalledTimes(3);
});
```
Vague name, tests mock not code
</Bad>

**Requirements:**
- One behavior
- Clear name
- Real code (no mocks unless unavoidable)

### Verify RED - Watch It Fail

**MANDATORY. Never skip.**

```bash
npm test path/to/test.test.ts
```

Confirm:
- Test fails (not errors)
- Failure message is expected
- Fails because feature missing (not typos)

**Test passes?** You're testing existing behavior. Fix test.

**Test errors?** Fix error, re-run until it fails correctly.

### GREEN - Minimal Code

Write simplest code to pass the test.

<Good>
```typescript
async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
  for (let i = 0; i < 3; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i === 2) throw e;
    }
  }
  throw new Error('unreachable');
}
```
Just enough to pass
</Good>

<Bad>
```typescript
async function retryOperation<T>(
  fn: () => Promise<T>,
  options?: {
    maxRetries?: number;
    backoff?: 'linear' | 'exponential';
    onRetry?: (attempt: number) => void;
  }
): Promise<T> {
  // YAGNI
}
```
Over-engineered
</Bad>

Don't add features, refactor other code, or "improve" beyond the test.

### Verify GREEN - Watch It Pass

**MANDATORY.**

```bash
npm test path/to/test.test.ts
```

Confirm:
- Test passes
- Other tests still pass
- Output pristine (no errors, warnings)

**Test fails?** Fix code, not test.

**Other tests fail?** Fix now.

### TRIANGULATE — Force Real Logic (mandatory for most tasks)

After GREEN: add a second test case with DIFFERENT inputs and expected outputs.

**Why:** GREEN can pass with Fake It (hardcoded return values). Triangulation forces real logic.

```typescript
// First test — GREEN passed with hardcoded return of 10
test('returns 10% discount for 5+ items', () => {
  expect(calculateDiscount(100, 5)).toBe(10);
});

// Triangulation: different inputs, must return 0 — hardcode of 10 now breaks
test('returns 0 discount for fewer than 5 items', () => {
  expect(calculateDiscount(100, 4)).toBe(0);
});
```

**Minimum:** 2 test cases per behavior (happy path + one edge case that exercises a different code path).

**Skip triangulation ONLY when ALL of these are true:**
- The task is purely structural (config file, constant definition, type export)
- There is literally ONE possible output (no branching, no logic)
- You write "Triangulation skipped: {reason}" in the Evidence Table

**Watch out for trivial GREEN:**
- Test passes because a loop iterates 0 times → NOT a real GREEN
- Test passes because the component is not rendered → NOT a real GREEN
- A real GREEN: production code RAN and produced the expected output

### REFACTOR - Clean Up

After green only:
- Remove duplication
- Improve names
- Extract helpers

Keep tests green. Don't add behavior.

### Repeat

Next failing test for next feature.

## Good Tests

| Quality | Good | Bad |
|---------|------|-----|
| **Minimal** | One thing. "and" in name? Split it. | `test('validates email and domain and whitespace')` |
| **Clear** | Name describes behavior | `test('test1')` |
| **Shows intent** | Demonstrates desired API | Obscures what code should do |

## Why Order Matters

**"I'll write tests after to verify it works"**

Tests written after code pass immediately. Passing immediately proves nothing:
- Might test wrong thing
- Might test implementation, not behavior
- Might miss edge cases you forgot
- You never saw it catch the bug

Test-first forces you to see the test fail, proving it actually tests something.

**"I already manually tested all the edge cases"**

Manual testing is ad-hoc. You think you tested everything but:
- No record of what you tested
- Can't re-run when code changes
- Easy to forget cases under pressure
- "It worked when I tried it" ≠ comprehensive

Automated tests are systematic. They run the same way every time.

**"Deleting X hours of work is wasteful"**

Sunk cost fallacy. The time is already gone. Your choice now:
- Delete and rewrite with TDD (X more hours, high confidence)
- Keep it and add tests after (30 min, low confidence, likely bugs)

The "waste" is keeping code you can't trust. Working code without real tests is technical debt.

**"TDD is dogmatic, being pragmatic means adapting"**

TDD IS pragmatic:
- Finds bugs before commit (faster than debugging after)
- Prevents regressions (tests catch breaks immediately)
- Documents behavior (tests show how to use code)
- Enables refactoring (change freely, tests catch breaks)

"Pragmatic" shortcuts = debugging in production = slower.

**"Tests after achieve the same goals - it's spirit not ritual"**

No. Tests-after answer "What does this do?" Tests-first answer "What should this do?"

Tests-after are biased by your implementation. You test what you built, not what's required. You verify remembered edge cases, not discovered ones.

Tests-first force edge case discovery before implementing. Tests-after verify you remembered everything (you didn't).

30 minutes of tests after ≠ TDD. You get coverage, lose proof tests work.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |
| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
| "Test hard = design unclear" | Listen to test. Hard to test = hard to use. |
| "TDD will slow me down" | TDD faster than debugging. Pragmatic = test-first. |
| "Manual test faster" | Manual doesn't prove edge cases. You'll re-test every change. |
| "Existing code has no tests" | You're improving it. Add tests for existing code. |

## Red Flags - STOP and Start Over

- Code before test
- Test after implementation
- Test passes immediately
- Can't explain why test failed
- Tests added "later"
- Rationalizing "just this once"
- "I already manually tested it"
- "Tests after achieve the same purpose"
- "It's about spirit not ritual"
- "Keep as reference" or "adapt existing code"
- "Already spent X hours, deleting is wasteful"
- "TDD is dogmatic, I'm being pragmatic"
- "This is different because..."

**All of these mean: Delete code. Start over with TDD.**

## Example: Bug Fix

**Bug:** Empty email accepted

**RED**
```typescript
test('rejects empty email', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email required');
});
```

**Verify RED**
```bash
$ npm test
FAIL: expected 'Email required', got undefined
```

**GREEN**
```typescript
function submitForm(data: FormData) {
  if (!data.email?.trim()) {
    return { error: 'Email required' };
  }
  // ...
}
```

**Verify GREEN**
```bash
$ npm test
PASS
```

**REFACTOR**
Extract validation for multiple fields if needed.

## Verification Checklist

Before marking work complete:

- [ ] Every new function/method has a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for expected reason (feature missing, not typo)
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass
- [ ] Output pristine (no errors, warnings)
- [ ] Tests use real code (mocks only if unavoidable)
- [ ] Edge cases and errors covered

Can't check all boxes? You skipped TDD. Start over.

## When Stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test | Write wished-for API. Write assertion first. Ask your human partner. |
| Test too complicated | Design too complicated. Simplify interface. |
| Must mock everything | Code too coupled. Use dependency injection. |
| Test setup huge | Extract helpers. Still complex? Simplify design. |

## Debugging Integration

Bug found? Write failing test reproducing it. Follow TDD cycle. Test proves fix and prevents regression.

Never fix bugs without a test.

## Testing Anti-Patterns

When adding mocks or test utilities, read @testing-anti-patterns.md to avoid common pitfalls:
- Testing mock behavior instead of real behavior
- Adding test-only methods to production classes
- Mocking without understanding dependencies

## Banned Assertion Patterns

These assertions prove nothing. Never write them:

```typescript
// TAUTOLOGIES — always pass, no production code involved
expect(true).toBe(true)
expect(1).toBe(1)

// TYPE-ONLY — existence, not behavior
expect(result).toBeDefined()     // assert the actual VALUE instead
expect(result).not.toBeNull()    // same

// GHOST LOOP — loop iterates 0 times, assertions never execute
const items = screen.queryAllByTestId('item'); // returns []
for (const item of items) {
  expect(item).toHaveTextContent('value');     // NEVER RUNS
}
// Fix: assert length first
expect(items).toHaveLength(3);

// CSS CLASSES — implementation detail, not behavior
expect(element.className).toContain('text-xs')
expect(element.style.color).toBe('red')

// SMOKE TEST — proves render only, not what the component does
render(<MyComponent />);
expect(screen.getByTestId('wrapper')).toBeInTheDocument();
```

**Mock hygiene:**
- ≤3 mocks → ✅ focused test
- 4–6 mocks → ⚠️ consider extracting logic to a pure function
- 7+ mocks → ❌ wrong test layer — extract the logic, test it without mocks

**Extract-Before-Mock Rule:** data transformation, filtering, or conditional logic →
extract to a pure function first, then test the function directly. Zero mocks needed.

## TDD Evidence Table

When working within `specai-subagent-driven-development`, include this table in your DONE report.
The verifier checks it.

| Task | Test File | Layer | Safety Net | RED | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------------|----------|
| 1.1 | `path/test.ts` | Unit | ✅ 5/5 | ✅ Written | ✅ 2 cases | ✅ Clean |
| 1.2 | `path/test.ts` | Integration | N/A (new) | ✅ Written | ➖ Single output | ✅ Clean |

Column values:
- **Safety Net:** "{N}/{N} passing" or "N/A (new file)"
- **RED:** "✅ Written" (if you didn't write it first, it's a TDD violation)
- **TRIANGULATE:** "✅ {N} cases" or "➖ Skipped: {reason}"
- **REFACTOR:** "✅ Clean" or "➖ None needed" or "✅ Extracted {what}"

## Final Rule

```
Production code → test exists and failed first
Otherwise → not TDD
```

No exceptions without your human partner's permission.
