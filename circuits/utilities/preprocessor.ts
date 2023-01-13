import { buildPoseidon } from "circomlibjs"

type JsonCircuitConfig = {
	stackDepth: number,
	numKeys: number,
	keyLengths: number[],
	numAttriExtracting: number,
	attrExtractingIndices: number[],
	attriTypes: number[],
	queryDepth: number,
};

type Ascii = number;
type AttributeQuery = string[];

type JsonCircuitInput = { 
	hashJsonProgram: string,
	json: Ascii[],
	keys: Ascii[][][];
	values: Ascii[][],
	keysOffsets: number[][][],
	valuesOffsets: number[][],
};

const ATTR_VAL_MAX_LENGTH = 10; // TODO: idk

function toAscii(str: string): Ascii[] {
	return [...str].map((_, i) => str.charCodeAt(i));
}

function padAscii(asciiArr: Ascii[], arrayLen: number): Ascii[] {
	if (asciiArr.length > arrayLen) {
		console.log(`asciiArr ${asciiArr} is longer than the backing array!!!`);
		return asciiArr.slice(0, arrayLen);
	} else {
		while (asciiArr.length < arrayLen) {
			asciiArr.push(0);
		}
		return asciiArr;
	}
}

function padAscii2D(asciiArr: Ascii[][][], stackDepth: number): Ascii[][][] {
	return asciiArr.map(arr => {
		const innerLength = arr[0].length;
		while (arr.length < stackDepth) {
			let a = new Array();
			for (let i=0; i<innerLength; i++) { a.push(0); }
			arr.push(a);
		}
		return arr;
	})
}

function checkAttributes(obj: {[key: string]: any}, attrQueries: AttributeQuery[]): boolean {
	if (attrQueries.length === 0) {
		console.error("Attribute queries empty!");
		return false;
	}
	
	const depth = attrQueries[0].length;
	const allDepthsEqual = attrQueries.map(x => x.length === depth).reduce((acc, c) => acc && c);
	if (!allDepthsEqual) {
		console.error("Not all query depths are equal!");
		return false;
	}

	// check that the queried keys exist
	for (const attrQuery of attrQueries) {
		let currObj = obj;
		for (const nestedAttr of attrQuery) {
			if (!(nestedAttr in currObj)) {
				console.error(`Nested attribute ${nestedAttr} of ${attrQuery} not found!`);
				return false;
			}
			currObj = currObj[nestedAttr];
		}
	}
	return true;
}

function extractValuesAscii(obj: Object, attrQueries: AttributeQuery[]): Ascii[][] {
	return attrQueries.map(attrQ => {
		const value = getValue(obj, attrQ);
		if (typeof(value) === "string") {
			return padAscii(toAscii(`"${value}"`), ATTR_VAL_MAX_LENGTH);
		} else if (typeof(value) === "number") {
			return padAscii(toAscii(value.toString()), ATTR_VAL_MAX_LENGTH); 
		}
	});
}

function getValue(obj: Object, attrQuery: AttributeQuery) {
	return attrQuery.reduce((acc, c) => acc[c], obj);
}

async function calculatePoseidon(json: Ascii[]): Promise<string> {
	const poseidon = await buildPoseidon();

	let numComponents = 1;
	if (json.length > 16) {
		const tmp = json.length - 17;
		numComponents = 2 + tmp;
		if (tmp % 15 !== 0) {
			numComponents++;
		}
	}

	let poseidonRes = poseidon(json.slice(0, 16));
	let i = 16;
	while (i < json.length) {
		poseidonRes = poseidon([poseidonRes].concat(json.slice(i, i+15)));
		i += 15;
	}
	return poseidon.F.toObject(poseidonRes).toString();
}

async function preprocessJson(
	obj: Object,
	attrQueries: AttributeQuery[],
	jsonProgramSize: number,
	stackDepth: number,
): Promise<JsonCircuitInput | null> {

	if (!checkAttributes(obj, attrQueries)) {
		console.error("Attribute check failed!");
		return null;
	} 

	const jsonString = JSON.stringify(obj);
	const jsonAscii = padAscii(toAscii(jsonString), jsonProgramSize);
	const queryDepth = attrQueries[0].length;

	const attributes = padAscii2D(attrQueries.map(attrQ =>
		attrQ.map(nestedAttr =>
			padAscii(toAscii(`"${nestedAttr}"`), ATTR_VAL_MAX_LENGTH))
	), stackDepth);

	const keysOffsets = padAscii2D(attrQueries.map(attrQ =>
		attrQ.map(nestedAttr => {
			const begin = jsonString.indexOf(`"${nestedAttr}"`);
			const end = begin + nestedAttr.length + 1;
			return [begin, end];
		})
	), stackDepth);

	// TODO: Undefined behavior if repeated keys¯\_(ツ)_/¯
	const values = extractValuesAscii(obj, attrQueries);
	const valuesOffsets: Ascii[][] = attrQueries.map(
		(attrQ, i) => { 
			// end index of the key + :" (2 chars)
			const begin = keysOffsets[i][queryDepth-1][1] + 2;
			const value = getValue(obj, attrQ);

			if (typeof(value) == 'string') {
				const end = jsonString.indexOf("\"", begin+1);
				return [begin, end];
			} else if (typeof(value) == 'number') {   
				let end = begin;
				while (end < jsonString.length) {
					const currChar = jsonString[end];
					if (!(currChar >= '0' && currChar <= '9')) {
						return [begin, end-1];
					}
					end++;
				}
			} else {
				console.error("Unsupported value type found while calculating offsets!");
				// return [begin, -1];
			}
		}
	);
	
	const hashJsonProgram = await calculatePoseidon(jsonAscii);
 
	const result = {
		hashJsonProgram,
		json: jsonAscii,
		keys: attributes,
		values,
		keysOffsets,
		valuesOffsets
	};

	return result;

}

function generateJsonCircuitConfig(
	obj: Object,
	attrQueries: AttributeQuery[]
): JsonCircuitConfig {
	const queryDepth = attrQueries[0].length;
	const attriTypes = attrQueries.map(attrQ => { 
		const value = getValue(obj, attrQ);
		if (typeof(value) == "number") {
			return 0;
		} else if (typeof(value) === "string") {
			return 1;
		} else {
			console.error(
				`Unsupported type ${typeof(value)} from ${attrQ}, value ${value}`);
			return -1;
		}
	});

	return { 
		stackDepth: 4, // TODO: hardcoded? 
		numKeys: attrQueries.length,
		keyLengths: [], // TODO: idt this is still needed?
		numAttriExtracting: queryDepth,
		attrExtractingIndices: [], // TODO: also dt it's needed anymore
		attriTypes,
		queryDepth,
	}
}

// let json = {"name":"foobar","value":123,"list":["a",1]} 
let json = {"name":"foobar","value":123,"map":{"a":"1"}}
preprocessJson(json, [["map", "a"]], 50, 3).then(res =>
	console.dir(res, {depth: null}));

