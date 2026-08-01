#!/usr/bin/env bash
# Read-only Java/JVM project discovery. It reports evidence; it does not run builds.
set -euo pipefail

usage() {
  printf 'Usage: %s [repository-or-module-root]\n' "$(basename "$0")"
}

case "${1:-.}" in
  -h|--help) usage; exit 0 ;;
esac
[ "$#" -le 1 ] || { usage >&2; exit 2; }
requested="${1:-.}"
[ -d "$requested" ] || { printf 'not a directory: %s\n' "$requested" >&2; exit 2; }
root="$(cd "$requested" && pwd -P)"

bool_file() { [ -f "$1" ] && printf 'yes' || printf 'no'; }
command_path() { command -v "$1" 2>/dev/null || printf 'unavailable'; }

print_evidence_matches() {
  local file="$1" limit="$2" pattern="$3" matches line
  matches="$(grep -nEim "$limit" "$pattern" "$file" 2>/dev/null || true)"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    line="$(printf '%s' "$line" | tr '\t' ' ' | cut -c1-220)"
    printf '%s:%s\n' "${file#$root/}" "$line"
  done <<< "$matches"
}

maven_wrapper=no
gradle_wrapper=no
maven_wrapper_executable=no
gradle_wrapper_executable=no
[ -f "$root/mvnw" ] && maven_wrapper=yes
[ -f "$root/gradlew" ] && gradle_wrapper=yes
[ -x "$root/mvnw" ] && maven_wrapper_executable=yes
[ -x "$root/gradlew" ] && gradle_wrapper_executable=yes
maven_descriptor="$(bool_file "$root/pom.xml")"
gradle_groovy="$(bool_file "$root/build.gradle")"
gradle_kotlin="$(bool_file "$root/build.gradle.kts")"
settings_groovy="$(bool_file "$root/settings.gradle")"
settings_kotlin="$(bool_file "$root/settings.gradle.kts")"

case "$maven_wrapper:$gradle_wrapper:$maven_wrapper_executable:$gradle_wrapper_executable" in
  yes:no:yes:*) build_system=maven ;;
  no:yes:*:yes) build_system=gradle ;;
  yes:yes:*:*) build_system=ambiguous-both-wrappers ;;
  yes:no:no:*) build_system=maven-wrapper-not-executable ;;
  no:yes:*:no) build_system=gradle-wrapper-not-executable ;;
  no:no:*:*)
    if [ "$maven_descriptor" = yes ] && [ "$gradle_groovy" = no ] && [ "$gradle_kotlin" = no ]; then
      build_system=maven-no-wrapper
    elif [ "$maven_descriptor" = no ] && { [ "$gradle_groovy" = yes ] || [ "$gradle_kotlin" = yes ]; }; then
      build_system=gradle-no-wrapper
    elif [ "$maven_descriptor" = yes ] || [ "$gradle_groovy" = yes ] || [ "$gradle_kotlin" = yes ]; then
      build_system=ambiguous-descriptors
    else
      build_system=none-detected
    fi
    ;;
esac

printf 'java-project-detect v1\n'
printf 'root=%s\n' "$root"
printf 'build.system=%s\n' "$build_system"
printf 'wrapper.maven=%s\n' "$maven_wrapper"
printf 'wrapper.gradle=%s\n' "$gradle_wrapper"
printf 'wrapper.maven.executable=%s\n' "$maven_wrapper_executable"
printf 'wrapper.gradle.executable=%s\n' "$gradle_wrapper_executable"
printf 'descriptor.pom=%s\n' "$maven_descriptor"
printf 'descriptor.gradle=%s\n' "$gradle_groovy"
printf 'descriptor.gradle-kts=%s\n' "$gradle_kotlin"
printf 'settings.gradle=%s\n' "$settings_groovy"
printf 'settings.gradle-kts=%s\n' "$settings_kotlin"
printf 'command.java=%s\n' "$(command_path java)"
printf 'command.javac=%s\n' "$(command_path javac)"
printf 'command.maven=%s\n' "$(command_path mvn)"
printf 'command.gradle=%s\n' "$(command_path gradle)"

if command -v java >/dev/null 2>&1; then
  runtime_version="$(java -version 2>&1 | { IFS= read -r line; printf '%s' "$line"; })"
  printf 'java.runtime=%s\n' "$runtime_version"
else
  printf 'java.runtime=unavailable\n'
fi
if command -v javac >/dev/null 2>&1; then
  printf 'javac.runtime=%s\n' "$(javac -version 2>&1 | { IFS= read -r line; printf '%s' "$line"; })"
else
  printf 'javac.runtime=unavailable\n'
fi

maven_properties="$root/.mvn/wrapper/maven-wrapper.properties"
gradle_properties="$root/gradle/wrapper/gradle-wrapper.properties"
printf 'wrapper.maven.properties=%s\n' "$(bool_file "$maven_properties")"
printf 'wrapper.gradle.properties=%s\n' "$(bool_file "$gradle_properties")"
if [ -f "$maven_properties" ]; then
  if grep -Eq '^[[:space:]]*distributionSha256Sum=' "$maven_properties"; then
    printf 'wrapper.maven.distribution-sha256=declared\n'
  else
    printf 'wrapper.maven.distribution-sha256=not-declared\n'
  fi
fi
if [ -f "$gradle_properties" ]; then
  if grep -Eq '^[[:space:]]*distributionSha256Sum=' "$gradle_properties"; then
    printf 'wrapper.gradle.distribution-sha256=declared\n'
  else
    printf 'wrapper.gradle.distribution-sha256=not-declared\n'
  fi
fi

printf 'evidence.jdk-target.begin\n'
for file in \
  "$root/pom.xml" \
  "$root/build.gradle" \
  "$root/build.gradle.kts" \
  "$root/gradle.properties" \
  "$root/.java-version" \
  "$root/.sdkmanrc" \
  "$root/.tool-versions"; do
  [ -f "$file" ] || continue
  print_evidence_matches "$file" 12 \
    'maven\.compiler\.(release|source|target)|<release>|<source>|<target>|<jdkToolchain>|<toolchain>|JavaLanguageVersion|languageVersion|sourceCompatibility|targetCompatibility|options\.release|java[._-]?version|^java[[:space:]]'
done
printf 'evidence.jdk-target.end\n'

printf 'evidence.ci.begin\n'
for ci in "$root"/.github/workflows/*.yml "$root"/.github/workflows/*.yaml "$root"/.gitlab-ci.yml "$root"/Jenkinsfile; do
  [ -f "$ci" ] || continue
  print_evidence_matches "$ci" 20 \
    'setup-java|java-version:|distribution:|(^|[[:space:]])\./mvnw([[:space:]]|$)|(^|[[:space:]])\./gradlew([[:space:]]|$)'
done
printf 'evidence.ci.end\n'

marker_files=()
for candidate in "$root/pom.xml" "$root/build.gradle" "$root/build.gradle.kts"; do
  [ -f "$candidate" ] && marker_files+=("$candidate")
done
if [ "${#marker_files[@]}" -gt 0 ]; then
  marker_text="$(grep -Eio 'junit-jupiter|junit-platform|mockito|testcontainers|spring-boot|maven-surefire|maven-failsafe|jacoco|spotbugs|checkstyle|pmd|errorprone|spotless|dependency-check' "${marker_files[@]}" 2>/dev/null || true)"
  if [ -n "$marker_text" ]; then
    printf 'markers=' 
    printf '%s\n' "$marker_text" | tr '[:upper:]' '[:lower:]' | sort -u | paste -sd, -
  else
    printf 'markers=none-detected\n'
  fi
else
  printf 'markers=none-detected\n'
fi

case "$build_system" in
  maven)
    printf "suggest.focused=./mvnw -Dtest='package.Type#method' test\n"
    printf 'suggest.module=./mvnw -pl module -am test\n'
    printf 'suggest.broad=./mvnw verify\n'
    ;;
  gradle)
    printf "suggest.focused=./gradlew test --tests 'package.Type.method'\n"
    printf 'suggest.module=./gradlew :module:test\n'
    printf 'suggest.broad=discover CI task; often ./gradlew check\n'
    ;;
  maven-no-wrapper)
    printf 'suggest.action=confirm repository instructions and installed Maven before running; do not create a wrapper implicitly\n'
    ;;
  gradle-no-wrapper)
    printf 'suggest.action=confirm repository instructions and installed Gradle before running; do not create a wrapper implicitly\n'
    ;;
  ambiguous-*)
    printf 'suggest.action=resolve the intended build root/system from repository instructions and CI; do not guess\n'
    ;;
  *-wrapper-not-executable)
    printf 'suggest.action=wrapper is present but not executable; inspect repository mode/instructions and do not substitute a system build tool\n'
    ;;
  *)
    printf 'suggest.action=no supported Java build root detected here\n'
    ;;
esac

printf 'note=read-only textual evidence; confirm descriptors, modules, toolchains, repository instructions, and CI before executing\n'
