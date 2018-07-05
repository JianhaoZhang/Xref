#jzhang91 & zsong6
#Project 4 Cross indexing

#The regex of OBJDUMP
objdump_reg_block = /([a-z0-9]+ <(\S+)>:)| *([a-z0-9]+):\t((?:[a-z0-9]{2} )+) *\t([a-z]+) *(\S*) *(# [a-z0-9]+ )*(<\S*>)*/
#The regex of DWARFDUMP
dwarfdump_reg = /(<pc> *\[lno,col\] NS BB ET PE EB IS= DI= uri: "filepath")|([a-z0-9]+) *\[ *(\d+), (\d+)\] *(NS)* *(BB)* *(ET)* *(PE)* *(EB)* *(IS=)* *(DI=)* *(uri: "(\S+)")*/
	
	executable = ARGV[0]
	if executable != nil then
	dwarf_command = "~cs254/bin/dwarfdump "+executable+" > DWARFDUMP"
	obj_command = "~cs254/bin/objdump -d "+executable+" > OBJDUMP"
	dump1 = system( dwarf_command )
	dump2 = system( obj_command )
		if dump1==true && dump2==true then
		objdump = IO.read("OBJDUMP")
		dwarfdump = IO.read("DWARFDUMP")
		objdump_match = objdump.scan(objdump_reg_block)
		dwarfdump_match = dwarfdump.scan(dwarfdump_reg)
		end
	end

	#used to record called functions that actually in my source code, default val is false, keys are function names
	used_func = Hash.new(false)
	#used to record src critical line numbers, default val is false, keys are file names
	src_lines = Hash.new(false)
	#used to record src call blocks index pairs, default val is false, keys are file names + last line number in a call block
	src_blocks = Hash.new(false)
	#used to validate if the given code block was traversed, false by default, keys are src index pairs+filename
	src_greys = Hash.new(false)

#Modify objdump array to bind function name to each line of Assembly code
cur_func = " "
for line in objdump_match do
	if line[0]!=nil then
		cur_func = line[1]
	elsif line[0]==nil then
		line[1]=cur_func
	else
	end
end

#Modify dwarfdump array to bind uri to each line of program counter
cur_dir = " "
for line in dwarfdump_match do
	if line[0]==nil && line[12]!=nil then
		cur_dir = line[12]
		
	elsif line[0]==nil && line[12]==nil then
		line[12]=cur_dir
	else
	end
end
	
	obj_hash = Hash[objdump_match.map {|v| [v[2],v]}]
	dwarf_hash = Hash[dwarfdump_match.map {|v| [v[1],v]}]

#Collect and redistribute line numbers to each files
dwarf_hash.each do |key, value|
	if value[12]!= nil then
		if src_lines[value[12]]== false then
			src_lines[value[12]]=Array.new
		end
	src_lines[value[12]]= src_lines[value[12]] << value[2].to_i
	end 
end

#Eliminate duplicates and sort
src_lines.each do |key, value|
	src_lines[key]=value.sort
	src_lines[key]=src_lines[key].uniq
end

#Loop through line numbers of each file and create index pairs, store to src_blocks(hash) as key=filename value=index start..end
src_lines.each do |key, value|
	cur_index = 1
	value.each do |v|
		src_blocks[key+v.to_s] =  [cur_index,v]
		cur_index = v+1
	end
end

#Read files' contents into files(hash) as key=filename value=array of lines
	files = Hash.new(false)
src_lines.each do |key, value|
	files[key] = File.readlines(key)
end


#full adress mask
addr_mask = "0x00000000"
html_body = ""

for line in objdump_match do

#OBJDUMP line that is the head of function block	
	if line[0]!=nil then
		key = addr_mask[0..1]+line[0][8..15]
		
		if dwarf_hash[key] != nil then
			used_func[line[1]]=true
			#html_body += '<a name="'+tag+'">'+"\n"
		end
	end
end

#tags(hash) key=address as target position in HTML, value=true or false
	tags = Hash.new(false)

#Collect the tags that should have a link position in HTML to be targeted
obj_hash.each do |key, value|
	
	if value[2]!=nil && used_func[value[1]]!=false then
		obcopy = obj_hash[value[5].to_s]
		if obcopy != nil && used_func[obcopy[1]]!=false then
			if (value[5] =~ /^[0-9a-f]+$/) then
				tags[value[5]]=true
			else
			end
		end
	else
	end
end

#first time do not print </td></tr>
first = true
int = 0

#The main production logic, loop through the objdump lines 
#and catch source code blocks that correspond to certain stream of Assembly code
for line in objdump_match do
	
	#OBJDUMP line that is Assembly code line
	if line[0]==nil then
		address = line[2].delete(' ')
		key = addr_mask[0..(9-address.length)]+address

		dcopy = dwarf_hash[key]

		if dcopy != nil then
			#print dcopy[2].to_s + " " + dcopy[3].to_s (test)
			if dcopy[12] != nil then
				low = src_blocks[dcopy[12]+dcopy[2].to_s][0].to_i-1
				high = src_blocks[dcopy[12]+dcopy[2].to_s][1].to_i-1
				grey_check = low.to_s+'|'+high.to_s+dcopy[12]
				#IF ET, skip src this iteration
				if dcopy[6]!="ET" || dcopy[4]!="NS" then
					if first == true then
						#no longer first time
						first = false
					else 
						#print table section end
						html_body += '</td>'+"\n"+'</tr>'
					end

					
					
					#print table section start
					if src_greys[grey_check]==false
						html_body += '<tr>'+"\n"+'<td>'
						src_greys[grey_check]=true
					elsif src_greys[grey_check]==true
						html_body += '<tr>'+"\n"+'<td class="grey">'
					else
					end

					
					if used_func[line[1]]==true then
						#if this address should be a tag, create HTML tag here
						if tags[line[2]]==true then
							html_body += '<a name="'+line[2]+'">'+"\n"
						end
					end
					
					for i in low..high
						
						xmlline = files[dcopy[12]][i].to_s
						xmlline.gsub! ' ', '&nbsp;'
						xmlline.gsub! '	', "\t"
						xmlline.gsub! "\n", ''
						xmlline.gsub! '<', '&lt;'
						xmlline.gsub! '>', '&gt;'
						html_body += xmlline + '<br>' + "\n"
						#print files[dcopy[12]][i].to_s (test)
					end
					
				html_body += '</td>'+ "\n" + '<td>' + "\n"
				#print "\n" (test)
				end
			end
			
		end
		
		#May only print to functions that are actually in my source code
		if used_func[line[1]]==true then
			
			if tags[line[5]]==false then
				html_body += line[4].to_s+" "+line[5] + '<br>' + "\n"
			#if branch target is successfully validated by tags(hash), create a link to the proposed position in HTML
			elsif tags[line[5]]==true then
				html_body += '<a href="#' + line[5] + '">' + line[4].to_s+" "+line[5].to_s + '</a><br>' + "\n"
			end
			#print line[4].to_s+" "+line[5].to_s+" "+line[6].to_s (test)
			#print "\n" (test)
		end
	
	
	else 

	end
end

html_body += '</td>' + "\n" + '</tr>'

html_head = '<!DOCTYPE html>
<html>
<head>
    <title>Assembly C</title>
    <style type="text/css">

        * { 
            font-family: monospace; 
            line-height: 1.5em;
        }

        table {
            width: 100%;
        }

        td
        {
            padding: 8px;
            border-bottom: 2px solid black;
            vertical-align: bottom;
            width: 50%;
        }

        th
        {
            border: 1px solid black;
        }

        .grey {
            color: #888
        }

    </style>
</head>
<body>
    <table>
'


html_tail = '</table>
</body>
</html>'

html_path = File.expand_path(File.dirname(__FILE__)) + "/output.html"

html = html_head
html += html_body
html += html_tail
File.write(html_path, html)

#print src_lines.to_s
#print src_blocks.to_s
#print used_func.to_s
#print tags.to_s

