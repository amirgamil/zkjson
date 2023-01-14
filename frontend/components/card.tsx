import { useEffect, useState } from "react";
import { getRecursiveKeyInDataStore, isJSONStore, JSON_EL, JSON_STORE } from "../utilities/json";

export function Card(props: { dataStore: JSON_STORE; setKeyInDataStore: any; keys: string[] }) {
    // jsonText

    const handleCheckmarkCheck = (keys: string[]) => {
        console.log("HELLLO");
        props.setKeyInDataStore(keys);
    };
    const [fetchJson, setFetchedJson] = useState<null | JSON_STORE | JSON_EL>(null);
    const [numKeys, setNumKeys] = useState<number>(0);

    useEffect(() => {
        setFetchedJson(getRecursiveKeyInDataStore(props.keys, props.dataStore));
        setNumKeys(Object.keys(getRecursiveKeyInDataStore(props.keys, props.dataStore)).length);
    });

    return (
        <>
            <ul className="ml-4 font-mono text-sm">
                <>
                    {fetchJson && isJSONStore(fetchJson) && (
                        <>
                            {Object.keys(getRecursiveKeyInDataStore(props.keys, props.dataStore)).map(
                                (key: string, index: any) => {
                                    return (
                                        <>
                                            {isJSONStore(fetchJson[key]) ? (
                                                <>
                                                    <span className="mb-4 ">{'"' + key + '"'}: &#123;</span>
                                                    <Card
                                                        dataStore={props.dataStore}
                                                        setKeyInDataStore={props.setKeyInDataStore}
                                                        keys={props.keys.concat([key])}
                                                    ></Card>
                                                    <span className="mb-4">
                                                        &#125;
                                                        {index != numKeys - 1 && <>,</>}
                                                    </span>
                                                </>
                                            ) : (
                                                <>
                                                    <div key={index}>
                                                        <span className="mb-4 mr-4">{'"' + key + '"'}: 
                                                        <button className={
                                                            fetchJson[key] && fetchJson[key].ticked ?
                                                                "hover:line-through decoration-pink-500 decoration-2" :
                                                                "line-through decoration-pink-500 decoration-2" }
                                                            onClick={() =>
                                                                handleCheckmarkCheck(props.keys.concat([key]))
                                                            }
                                                        >
                                                        {
                                                                key in fetchJson && 
                                                                fetchJson[key] && <>{
                                                                    "value" in fetchJson[key] &&
                                                                    typeof fetchJson[key]['value'] === 'string' ?
                                                                    '"' + fetchJson[key]['value'] + '"' :
                                                                    fetchJson[key]['value']    
                                                                }</>
                                                        }
                                                        {index != numKeys - 1 && <>,</>}
                                                        </button>
                                                        </span>
                                                        {/* <label className="inline-flex items-center">
                                                            <input 
                                                                className="form-check-input appearance-none h-4 w-4 border border-gray-300 rounded-sm bg-white checked:bg-blue-600 checked:border-blue-600 focus:outline-none transition duration-200 mt-1 align-top bg-no-repeat bg-center bg-contain float-left mr-2 cursor-pointer"
                                                                // className="form-check-input appearance-none h-4 w-4 border border-gray-300 rounded-sm bg-white checked:bg-blue-600 checked:border-blue-600 focus:outline-none transition duration-200 mt-1 align-top bg-no-repeat bg-center bg-contain float-left mr-2 cursor-pointer"
                                                                type="checkbox" 
                                                                onChange={(e) =>
                                                                    handleCheckmarkCheck(e, props.keys.concat([key]))
                                                                }
                                                                checked={
                                                                    fetchJson[key] && fetchJson[key].ticked
                                                                        ? true
                                                                        : false
                                                                }
                                                                id="flexCheckDefault"
                                                            ></input>
                                                        </label> */}
                                                    </div>
                                                </>
                                            )}
                                        </>
                                    );
                                }
                            )}
                        </>
                    )}
                </>
            </ul>
        </>
    );
}
