import { useEffect, useState } from "react";
import { getRecursiveKeyInDataStore, isJSONStore, JSON_EL, JSON_STORE } from "../utilities/json";

export function Card(props: { dataStore: JSON_STORE; setKeyInDataStore: any; keys: string[] }) {
    // jsonText

    const handleCheckmarkCheck = (event: React.ChangeEvent<HTMLInputElement>, keys: string[]) => {
        props.setKeyInDataStore(keys, event.target.checked);
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
                                                        {
                                                            key in fetchJson && fetchJson[key]
                                                                && typeof fetchJson[key]['value'] === 'string' ?
                                                                '"' + fetchJson[key]['value'] + '"' :
                                                                fetchJson[key]['value']
                                                        }
                                                        {
                                                            (() => {
                                                                console.log("100000000000000000", fetchJson[key]);
                                                                return <></>;
                                                            })()
                                                        }
                                                        {index != numKeys - 1 && <>,</>}
                                                        </span>
                                                        <label className="inline-flex items-center">
                                                            <input
                                                                type="checkbox"
                                                                className="mr-4 pt-2 form-checkbox h-4 w-4 text-indigo-600 transition duration-150 ease-in-out"
                                                                onChange={(e) =>
                                                                    handleCheckmarkCheck(e, props.keys.concat([key]))
                                                                }
                                                                checked={
                                                                    fetchJson[key] && fetchJson[key].ticked
                                                                        ? true
                                                                        : false
                                                                }
                                                            />
                                                        </label>
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
