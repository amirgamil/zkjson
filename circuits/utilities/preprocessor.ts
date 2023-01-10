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

// TODO: update offsets to now include quotes for strings
function preprocessJson(obj: Object, attributes: string[]): JsonCircuitInput | null {
	for (const attr of attributes) {
		if (!(attr in obj)) {
			return null;
		}
	}

	const jsonString = JSON.stringify(obj);
	const jsonAscii: Ascii[] =
		[...jsonString].map((_, i) => jsonString.charCodeAt(i));  
	const keysOffsets = attributes.map(attr => { 
		const begin = jsonString.indexOf(attr);
		const end = begin + attr.length - 1;
		return [begin, end];
	})

	const valuesOffsets = keysOffsets.map(keyOffset => {
		const begin = keyOffset[1] + 4;
		const end = jsonString.indexOf("\"", begin) - 1;
		return [begin, end];
	})

	const preprocessAttrs = attributes.map(attr => {
		let res: Ascii[] = [];
		for (let i = 0; i < ATTR_VAL_MAX_LENGTH; i++) {
			if (i < attr.length) {
				res.push(attr.charCodeAt(i));
			} else {
				res.push(0);
			}
		}
		return res;
	});

	const values = valuesOffsets.map(valueOffset => {
		const valString = jsonString.substring(valueOffset[0], valueOffset[1]+1);
		let res: Ascii[] = [];
		for (let i = 0; i < ATTR_VAL_MAX_LENGTH; i++) {
			if (i < valString.length) {
				res.push(valString.charCodeAt(i));
			} else {
				res.push(0);
			}
 		} 
		return res;
	});

	const result = {
		jsonAscii,
		attributes: preprocessAttrs,
		values,
		keysOffsets,
		valuesOffsets
	};

	return result;
  
}

let json = { "hello": "world", "good": "bye"};
console.log(preprocessJson(json, ["good"]));
