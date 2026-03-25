# NestJS DTO Validation Analysis

> Analyze DTO structure, class-validator usage, class-transformer patterns, and Swagger documentation.

---

Goal: Analyze DTO files for proper validation, transformation, and
documentation.

STANDARDS SOURCE:
- Validates against:
     `https://raw.githubusercontent.com/somnio-software/cursor-rules/main/.cursor/rules/nestjs/nestjs-dto-validation.mdc`

INSTRUCTIONS:
1. USE the `read_url_content` tool to fetch the latest standards
   from the URL above.
2. Proceed with the analysis below using strict adherence to those rules.

ANALYSIS TARGETS:
1.  **Validation Decorators**:
    *   **Required Fields**: Check for @IsNotEmpty on required fields.
    *   **Type Validation**: Check for @IsString, @IsNumber, @IsEmail,
        @IsEnum, etc.
    *   **Optional Fields**: Verify @IsOptional on optional properties.
    *   **Nested Validation**: Check for @ValidateNested + @Type on
        nested objects.
    *   **Array Validation**: Verify { each: true } for array validation.

2.  **Transformation Decorators**:
    *   **@Type**: Check for @Type decorator on nested objects and dates.
    *   **@Expose/@Exclude**: Verify response DTOs control exposed fields.
    *   **@Transform**: Check for proper transformation functions.

3.  **Swagger Documentation**:
    *   **@ApiProperty**: Verify every property has @ApiProperty or
        @ApiPropertyOptional.
    *   **Examples**: Check for example values in ApiProperty.
    *   **Descriptions**: Verify meaningful descriptions.
    *   **Enum Documentation**: Check for enum and enumName properties.

4.  **DTO Organization**:
    *   **Separate DTOs**: Check for create, update, query, response DTOs.
    *   **PartialType Usage**: Verify PartialType/OmitType/PickType for
        update DTOs.
    *   **Readonly Properties**: Check for readonly on DTO properties.

5.  **Security Patterns**:
     *   **Response DTOs**: Verify passwords, hashes, tokens are not
       exposed.
    *   **@Exclude on Class**: Check for @Exclude() on response DTO class.
    *   **Sensitive Fields**: Flag any sensitive data in response DTOs.

OUTPUT FORMAT:
*   **DTO Score**: (1-10) based on validation and documentation quality.
*   **Violations**:
    *   `[Validation Issue]` [file:line]: Missing or incorrect validator.
     *   `[Swagger Issue]` [file:line]: Missing @ApiProperty or
       description.
    *   `[Security Issue]` [file:line]: Sensitive data exposure risk.
     *   `[Structure Issue]` [file:line]: Missing DTO separation or
       improper
        inheritance.
*   **Recommendations**: Specific fixes for each violation type.
