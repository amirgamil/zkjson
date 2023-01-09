# Given a string, convert it to an array of unicode characters
def string_to_array(json):
    return [ord(x) for x in json]

def dict_to_string(dictionary):
    # remove spaces and replace single quotes with double quotes
    string = str(dictionary)
    string = string.replace("'", '"')
    string = string.replace(" ", "")
    return string

def generate_test(dictionary, indices, N=10):
    # generate a testcase from a dictionary and a sorted list of indices
    string = dict_to_string(dictionary)
    ascii_string = string_to_array(string)
    print(f"Example({len(string)}, {len(dictionary)}, {[len(k) for k in dictionary.keys()]}, {len(indices)}, {indices});\n")
    print("/* INPUT = {")
    print(f"\t\"JSON\": {ascii_string},")
    key_vals = []
    index = 0
    for key in dictionary.keys():
        if index in indices:
            val = dictionary[key]
            key_vals.append((key, val))
        index += 1
    attr_arr = []
    for pair in key_vals:
        arr = string_to_array(pair[0])
        arr = arr + [0,] * (N - len(arr))
        attr_arr.append(arr)
    print(f"\t\"attributes\": {attr_arr},")
    value_arr = []
    for pair in key_vals:
        arr = string_to_array(pair[1])
        arr = arr + [0,] * (N - len(arr))
        value_arr.append(arr)
    print(f"\t\"values\": {value_arr},")
    pair_strings = [f"\"{p[0]}\":\"{p[1]}\"" for p in key_vals]
    indices = [string.index(p) for p in pair_strings]
    key_offsets = [[index + 1, index + len(key_vals[i][0])] for i, index in enumerate(indices)]
    print(f"\t\"keysOffset\": {key_offsets},")
    val_offsets = [[index + len(key_vals[i][0])+4, index + len(key_vals[i][0])+3+len(key_vals[i][1])] for i, index in enumerate(indices)]
    print(f"\t\"valuesOffset\": {val_offsets}")
    print("} */")

d = dict()
d["name"] = "foobar"
d["value"] = "123"
generate_test(d, [0,1])