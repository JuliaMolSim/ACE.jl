

using JuLIP, SHIPs
import ZipFile, JSON

zipname = dirname(pathof(SHIPs))[1:end-3] * "test/models/v07_compat.zip"
zipdir = ZipFile.Reader(zipname)

fptr = zipdir.files[1]

D = JSON.parse(fptr)
calc =


for fptr in zipdir.files
   @info("Testing $(fptr.name)")
   D = JSON.parse(fptr)
   calc = read_dict(D)
   
end
