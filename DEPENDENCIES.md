# Dependencies

This repository contains CloudFormation templates and Python-based AWS Lambda functions for deploying MarkLogic clusters on AWS.

## Technology Stack

### Primary Languages
- **Python 3.9** - Lambda functions
- **YAML/JSON** - CloudFormation templates
- **Shell** - Build scripts

### Python Dependencies

The Lambda functions use the following Python packages (bundled in `lambda/package/custom_resource_base.zip`):

- **boto3** - AWS SDK for Python
- **botocore** - Low-level interface to AWS services
- **certifi** (2024.7.4) - SSL certificates
- **urllib3** - HTTP client
- **chardet** - Character encoding detection
- **requests** (2.32.4) - HTTP library
- **cfn_resource_timeout** (1.2.0) - CloudFormation custom resource timeout handler
- **idna** (3.7) - Internationalized Domain Names
- **setuptools** (80.9.0) - Package management
- **wheel** (0.43.0) - Package format

## Java Dependencies

**This repository does NOT contain any Java dependencies.**

- No Maven (pom.xml) configuration
- No Gradle (build.gradle) configuration
- No JAR files
- No Java source code
- No Java-based Lambda functions

## Security Notes

If a security vulnerability is reported for a Java library (such as json-smart, log4j, etc.), it does not apply to this repository unless:

1. The vulnerability is in the MarkLogic Server binaries deployed by these templates (in which case, upgrade MarkLogic Server version)
2. The vulnerability is in CI/CD build tools (separate from this source code)
3. The report was filed for the wrong repository

## Updating Dependencies

To update Python dependencies:
1. Update packages in the Lambda function packaging scripts
2. Rebuild the `lambda/package/custom_resource_base.zip`
3. Test Lambda functions with updated dependencies
4. Update this DEPENDENCIES.md file with new versions

---
**Last Updated**: 2024-12-12
