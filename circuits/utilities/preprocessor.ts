type JsonCircuitConfig = {
	jsonLength: number,
	numKeys: number,
	attrLengths: number[], 
	numAttriExtracting: number,
	attrExtractingIndices: number[],
};

type Ascii = number;
type KeyOffset = {
	start: number,
	end: number,
};
type ValueOffset = { 
	start: number,
	end: number,
}

type JsonCircuitInput = { 
	jsonAscii: Ascii[],
	attributes: Ascii[][], 
	values: Ascii[][],
	keysOffsets: number[][],
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

function preprocessJson(obj: Object, attributes: string[]): JsonCircuitInput | null {

	for (const attr of attributes) {
		if (!(attr in obj)) {
			return null;
		}
	}

	const jsonString = JSON.stringify(obj);
	const jsonAscii = toAscii(jsonString);

	const keysOffsets = attributes.map(attr => { 
		const begin = jsonString.indexOf(`"${attr}"`);
		const end = begin + attr.length + 1;
		return [begin, end];
	})

	const valueOffsetTuples = attributes.map((attr, i) => {
		const begin = keysOffsets[i][1] + 2;
		if (typeof(obj[attr]) === 'string') {
			const end = jsonString.indexOf("\"", begin+1);
			return [begin, end, padAscii(toAscii(jsonString.substring(begin, end+1)), ATTR_VAL_MAX_LENGTH)];
		} else if (typeof(obj[attr]) === 'number') {
			let end = begin;
			while (end < jsonString.length) {
				const currChar = jsonString[end];
				if (!(currChar >= '0' && currChar <= '9')) {
					return [begin, end-1, padAscii([parseInt(jsonString.substring(begin, end))], ATTR_VAL_MAX_LENGTH)];
				}
				end++;
			}
		} else if (Array.isArray(obj[attr])) {
			let end = begin;
			while (end < jsonString.length) {
				const currChar = jsonString[end];
				if (currChar == "]") {
					return [begin, end, padAscii(toAscii(jsonString.substring(begin, end+1)), ATTR_VAL_MAX_LENGTH)]
				}
				end++;
			}
		}
	})

	const values = valueOffsetTuples.map(t => t[2] as number[]);
	const valuesOffsets = valueOffsetTuples.map(t => [t[0], t[1]] as number[]);
	const preprocessAttrs = attributes.map(attr => padAscii(toAscii(attr), ATTR_VAL_MAX_LENGTH));

	const result = {
		jsonAscii,
		attributes: preprocessAttrs,
		values,
		keysOffsets,
		valuesOffsets
	};

	return result;

}

let json = {"name":"foobar","value":123,"list":["a",1]} 
console.log(preprocessJson(json, ["name", "value", "list"]));

