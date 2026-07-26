# Official guidance used by `java-development`

Checked 2026-07-23. Prefer the repository's locked-version documentation over a
versionless “current” page. These links are evidence for the workflow contract,
not a claim that every tool belongs in every project.

## Build and toolchains

- [Maven Wrapper](https://maven.apache.org/wrapper/)
- [Maven lifecycle](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html)
- [Maven Toolchains](https://maven.apache.org/guides/mini/guide-using-toolchains.html)
- [Maven Failsafe](https://maven.apache.org/surefire/maven-failsafe-plugin/)
- [Maven dependency analysis](https://maven.apache.org/plugins/maven-dependency-plugin/analyze-mojo.html)
- [Gradle Wrapper](https://docs.gradle.org/current/userguide/gradle_wrapper.html)
- [Gradle JVM toolchains](https://docs.gradle.org/current/userguide/toolchains.html)
- [Gradle JVM Test Suite plugin](https://docs.gradle.org/current/userguide/jvm_test_suite_plugin.html)
- [Gradle dependency locking](https://docs.gradle.org/current/userguide/dependency_locking.html)
- [Gradle dependency verification](https://docs.gradle.org/current/userguide/dependency_verification.html)

## Tests, analysis, coverage, and frameworks

- [JUnit 5 overview (versioned)](https://docs.junit.org/5.14.3/overview.html)
- [JUnit 5 build support (versioned)](https://docs.junit.org/5.14.3/running-tests/build-support.html)
- [JUnit parallel execution](https://docs.junit.org/current/writing-tests/parallel-execution.html)
- [Mockito core documentation](https://javadoc.io/doc/org.mockito/mockito-core/latest/org.mockito/org/mockito/Mockito.html)
- [Mockito JUnit Jupiter extension](https://javadoc.io/doc/org.mockito/mockito-junit-jupiter/latest/org.mockito.junit.jupiter/org/mockito/junit/jupiter/MockitoExtension.html)
- [Testcontainers JUnit 5 integration](https://java.testcontainers.org/test_framework_integration/junit_5/)
- [Testcontainers reuse](https://java.testcontainers.org/features/reuse/)
- [Checkstyle](https://checkstyle.org/)
- [SpotBugs](https://spotbugs.readthedocs.io/en/latest/)
- [PMD](https://pmd.github.io/)
- [Error Prone installation](https://errorprone.info/docs/installation)
- [Spotless](https://github.com/diffplug/spotless)
- [OWASP Dependency-Check](https://jeremylong.github.io/DependencyCheck/)
- [JaCoCo Maven plugin](https://www.jacoco.org/jacoco/trunk/doc/maven.html)
- [JaCoCo Maven coverage checks](https://www.jacoco.org/jacoco/trunk/doc/check-mojo.html)
- [Gradle JaCoCo plugin](https://docs.gradle.org/current/userguide/jacoco_plugin.html)
- [Spring Boot testing](https://docs.spring.io/spring-boot/reference/testing/index.html)
- [Spring Boot application tests](https://docs.spring.io/spring-boot/reference/testing/spring-boot-applications.html)
- [Spring Boot Testcontainers](https://docs.spring.io/spring-boot/reference/testing/testcontainers.html)

## Compiler, debugger, and language server

- [`javac` options](https://docs.oracle.com/en/java/javase/26/docs/specs/man/javac.html)
- [JPDA/JDWP connectors](https://docs.oracle.com/en/java/javase/26/docs/specs/jpda/conninv.html)
- [Eclipse JDT Language Server](https://github.com/eclipse-jdtls/eclipse.jdt.ls)
- [Microsoft Java debug server](https://github.com/microsoft/java-debug)

## Compatibility cautions

- Versionless JUnit documentation currently covers JUnit 6, while many existing
  projects remain on JUnit 5. Match the locked BOM/modules and required Java
  version before using examples.
- Current Spring Boot documentation may describe Boot 4/JUnit 6-era APIs.
  Annotation packages and integrations vary by Boot major.
- Eclipse JDT LS currently needs a newer runtime JDK than many projects target;
  its runtime and the project's compilation toolchain are separate concerns.
- Error Prone's runtime-JDK requirement may be newer than the project's target.
  Preserve configured build behavior rather than installing it ad hoc.
