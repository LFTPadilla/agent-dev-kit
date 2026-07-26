#!/usr/bin/env bash
# Contract and disposable-fixture tests for the Java development capability.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/plugins/dev-skills/skills/java-development/SKILL.md"
DETECT="$ROOT/plugins/dev-skills/skills/java-development/scripts/java-project-detect.sh"
REFERENCES="$ROOT/plugins/dev-skills/skills/java-development/references/official-guidance.md"
PROFILE="$ROOT/profiles/personal-dev-tutor.yml"
LIB="$ROOT/scripts/personal-tutor-lib.sh"

for file in "$SKILL" "$DETECT" "$REFERENCES" "$PROFILE" "$LIB"; do
  [ -f "$file" ] || { printf 'FAIL missing %s\n' "${file#$ROOT/}"; exit 1; }
done
[ -x "$DETECT" ] || { echo 'FAIL Java detector is not executable'; exit 1; }
bash -n "$DETECT"

grep -q '^name: java-development$' "$SKILL"
grep -q 'Discover before executing' "$SKILL"
grep -q 'Use the project wrapper' "$SKILL"
grep -q 'Honor the pinned JDK' "$SKILL"
grep -q 'Diagnose before patching' "$SKILL"
grep -q 'focused test' "$SKILL"
grep -q 'Surefire/Failsafe' "$SKILL"
grep -q 'Testcontainers' "$SKILL"
grep -q 'Context7 only for a version-sensitive' "$SKILL"
grep -q 'Graphify only when its Java parser' "$SKILL"
grep -q 'Do not edit generated sources' "$SKILL"
grep -q 'PROJECT / CI-PARITY VERIFICATION' "$SKILL"
grep -q 'maven.apache.org/wrapper' "$REFERENCES"
grep -q 'docs.gradle.org/current/userguide/gradle_wrapper' "$REFERENCES"
grep -q 'docs.junit.org/5' "$REFERENCES"
grep -q 'java.testcontainers.org' "$REFERENCES"
grep -q 'eclipse-jdtls' "$REFERENCES"

python3 - "$PROFILE" "$LIB" <<'PY'
from pathlib import Path
import re
import sys

profile = Path(sys.argv[1]).read_text()
lib = Path(sys.argv[2]).read_text()
include = profile.split("include_skills:\n", 1)[1].split("codex_worker_skills:\n", 1)[0]
worker = profile.split("codex_worker_skills:\n", 1)[1].split("external_skills:\n", 1)[0]
if include.count("  - java-development\n") != 1:
    raise SystemExit("FAIL profile include_skills must contain java-development exactly once")
if worker.count("  - java-development\n") != 1:
    raise SystemExit("FAIL profile codex_worker_skills must contain java-development exactly once")
match = re.search(r"PERSONAL_TUTOR_CODEX_SKILLS=\((.*?)\n\)", lib, re.S)
if not match or len(re.findall(r"\bjava-development\b", match.group(1))) != 1:
    raise SystemExit("FAIL runtime Codex allowlist must contain java-development exactly once")
PY

grep -q '"java-development"' "$ROOT/skill-provenance.json"
grep -q '`java-development`' "$ROOT/docs/skills-catalog.md"
grep -q '"test:java"' "$ROOT/package.json"

fixture="$(mktemp -d)"
cleanup() { rm -rf "$fixture"; }
trap cleanup EXIT
mkdir -p "$fixture/maven/.mvn/wrapper" "$fixture/maven/.github/workflows"
printf '#!/usr/bin/env sh\nexit 99\n' > "$fixture/maven/mvnw"
chmod +x "$fixture/maven/mvnw"
cat > "$fixture/maven/.mvn/wrapper/maven-wrapper.properties" <<'EOF'
distributionUrl=https://repo.maven.apache.org/maven2/example.zip
distributionSha256Sum=0123456789abcdef
EOF
cat > "$fixture/maven/pom.xml" <<'EOF'
<project>
  <properties><maven.compiler.release>17</maven.compiler.release></properties>
  <dependencies>
    <dependency><artifactId>junit-jupiter</artifactId></dependency>
  </dependencies>
  <build><plugins>
    <plugin><artifactId>maven-surefire-plugin</artifactId></plugin>
    <plugin><artifactId>maven-failsafe-plugin</artifactId></plugin>
    <plugin><artifactId>jacoco-maven-plugin</artifactId></plugin>
  </plugins></build>
</project>
EOF
cat > "$fixture/maven/.github/workflows/verify.yml" <<'EOF'
steps:
  - uses: actions/setup-java@v5
    with:
      distribution: temurin
      java-version: '17'
  - run: ./mvnw verify
EOF
before="$(find "$fixture/maven" -type f -print0 | sort -z | xargs -0 sha256sum)"
maven_report="$($DETECT "$fixture/maven")"
after="$(find "$fixture/maven" -type f -print0 | sort -z | xargs -0 sha256sum)"
[ "$before" = "$after" ] || { echo 'FAIL detector modified Maven fixture'; exit 1; }
printf '%s\n' "$maven_report" | grep -q '^build.system=maven$'
printf '%s\n' "$maven_report" | grep -q '^wrapper.maven.distribution-sha256=declared$'
printf '%s\n' "$maven_report" | grep -q 'maven.compiler.release'
printf '%s\n' "$maven_report" | grep -q 'setup-java'
printf '%s\n' "$maven_report" | grep -q 'markers=.*junit-jupiter'
printf '%s\n' "$maven_report" | grep -q "suggest.focused=./mvnw"

mkdir -p "$fixture/gradle/gradle/wrapper"
printf '#!/usr/bin/env sh\nexit 99\n' > "$fixture/gradle/gradlew"
chmod +x "$fixture/gradle/gradlew"
cat > "$fixture/gradle/gradle/wrapper/gradle-wrapper.properties" <<'EOF'
distributionUrl=https\://services.gradle.org/distributions/gradle-example-bin.zip
distributionSha256Sum=abcdef0123456789
EOF
cat > "$fixture/gradle/settings.gradle.kts" <<'EOF'
rootProject.name = "fixture"
EOF
cat > "$fixture/gradle/build.gradle.kts" <<'EOF'
plugins { java; jacoco }
java { toolchain { languageVersion = JavaLanguageVersion.of(21) } }
dependencies { testImplementation("org.testcontainers:junit-jupiter:0") }
tasks.test { useJUnitPlatform() }
EOF
gradle_report="$($DETECT "$fixture/gradle")"
printf '%s\n' "$gradle_report" | grep -q '^build.system=gradle$'
printf '%s\n' "$gradle_report" | grep -q '^wrapper.gradle.distribution-sha256=declared$'
printf '%s\n' "$gradle_report" | grep -q 'JavaLanguageVersion'
printf '%s\n' "$gradle_report" | grep -q 'markers=.*testcontainers'
printf '%s\n' "$gradle_report" | grep -q "suggest.focused=./gradlew"

mkdir -p "$fixture/ambiguous"
printf '#!/usr/bin/env sh\nexit 99\n' > "$fixture/ambiguous/mvnw"
printf '#!/usr/bin/env sh\nexit 99\n' > "$fixture/ambiguous/gradlew"
chmod +x "$fixture/ambiguous/mvnw" "$fixture/ambiguous/gradlew"
ambiguous_report="$($DETECT "$fixture/ambiguous")"
printf '%s\n' "$ambiguous_report" | grep -q '^build.system=ambiguous-both-wrappers$'
printf '%s\n' "$ambiguous_report" | grep -q 'resolve the intended build root/system'

mkdir -p "$fixture/no-wrapper"
printf '<project/>\n' > "$fixture/no-wrapper/pom.xml"
no_wrapper_report="$($DETECT "$fixture/no-wrapper")"
printf '%s\n' "$no_wrapper_report" | grep -q '^build.system=maven-no-wrapper$'
printf '%s\n' "$no_wrapper_report" | grep -q 'do not create a wrapper implicitly'

mkdir -p "$fixture/non-executable-wrapper"
printf '<project/>\n' > "$fixture/non-executable-wrapper/pom.xml"
printf '#!/usr/bin/env sh\nexit 0\n' > "$fixture/non-executable-wrapper/mvnw"
chmod 0644 "$fixture/non-executable-wrapper/mvnw"
non_executable_report="$($DETECT "$fixture/non-executable-wrapper")"
printf '%s\n' "$non_executable_report" | grep -q '^build.system=maven-wrapper-not-executable$'
printf '%s\n' "$non_executable_report" | grep -q '^wrapper.maven.executable=no$'
printf '%s\n' "$non_executable_report" | grep -q 'do not substitute a system build tool'

if command -v javac >/dev/null 2>&1 && command -v java >/dev/null 2>&1; then
  mkdir -p "$fixture/plain/src/example" "$fixture/plain/classes"
  cat > "$fixture/plain/src/example/FocusedFixture.java" <<'EOF'
package example;
public final class FocusedFixture {
  static int twice(int value) { return value * 2; }
  public static void main(String[] args) {
    if (twice(21) != 42) throw new AssertionError("focused fixture failed");
    System.out.println("JAVA_FIXTURE_PASS");
  }
}
EOF
  javac --release 17 -d "$fixture/plain/classes" "$fixture/plain/src/example/FocusedFixture.java"
  java_output="$(java -cp "$fixture/plain/classes" example.FocusedFixture)"
  [ "$java_output" = JAVA_FIXTURE_PASS ] || { echo 'FAIL disposable Java fixture'; exit 1; }
  if command -v javap >/dev/null 2>&1; then
    javap -verbose "$fixture/plain/classes/example/FocusedFixture.class" | grep -q 'major version: 61'
  fi
  printf 'PASS disposable Java fixture compiled with --release 17 and executed\n'
else
  printf 'SKIP disposable Java compilation: java/javac unavailable; static contracts passed\n'
fi

printf 'PASS java-development workflow contract\n'
