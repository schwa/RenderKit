import matplotlib.pyplot as plt
from pydicom import dcmread
from pathlib import Path
import json

d = Path("/Users/schwa/Downloads/Covid Scans/Subject (1)/98.12.2")
output = Path("/Users/schwa/Downloads/Output")
output.mkdir(exist_ok=True)

shape = None
files = []
largest_value = 0

Largest_Image_Pixel_Value = (0x0028, 0x0107)

for p in sorted(d.glob("*.dcm")):
    ds = dcmread(p)
#    print(ds);
    if 'SliceLocation' in ds:
        largest_value = max(ds[Largest_Image_Pixel_Value].value, largest_value)
        arr = ds.pixel_array
        if shape == None:
            shape = arr.shape
        else:
            assert shape == arr.shape
        file_name = f"slice_{len(files)}.raw"
        files.append(file_name)
        arr.astype('int16').tofile(output / file_name)

j = {"shape": [*shape, len(files)], "files": files, "largest_value": largest_value}
print(largest_value)
json.dump(j, open(output / "meta.json", "w"))
