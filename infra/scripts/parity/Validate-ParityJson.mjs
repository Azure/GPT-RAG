import fs from "node:fs";
import path from "node:path";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const [, , schemaArgument, documentArgument] = process.argv;
if (!schemaArgument || !documentArgument) {
  console.error("Usage: node Validate-ParityJson.mjs <schema> <document>");
  process.exit(2);
}

function loadJson(filePath, label) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    console.error(`${label} '${filePath}' is not valid JSON: ${error.message}`);
    process.exit(1);
  }
}

const schemaPath = path.resolve(schemaArgument);
const documentPath = path.resolve(documentArgument);
const schema = loadJson(schemaPath, "Schema");
const document = loadJson(documentPath, "Document");
const ajv = new Ajv2020({
  allErrors: true,
  strict: false,
  validateFormats: true,
});
addFormats(ajv);

let validate;
try {
  validate = ajv.compile(schema);
} catch (error) {
  console.error(`Schema '${schemaPath}' could not be compiled: ${error.message}`);
  process.exit(1);
}

if (!validate(document)) {
  const errors = [...validate.errors]
    .sort((left, right) =>
      `${left.instancePath}|${left.keyword}|${left.message}`.localeCompare(
        `${right.instancePath}|${right.keyword}|${right.message}`,
      ),
    )
    .map((error) => {
      const location = error.instancePath || "/";
      return `${location}: ${error.message}`;
    });
  console.error(`Schema validation failed for '${documentPath}':\n${errors.join("\n")}`);
  process.exit(1);
}

console.log(`Schema validation passed: ${documentPath}`);
