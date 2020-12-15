cmake_minimum_required(VERSION
	#3.10.3 # include_guard()
	#3.12.4 # list(SUBLIST ...)
	3.17.5 # foreach(loop-var... IN ZIP_LISTS <lists>...)
) 

include_guard()

function(generate_code_to_embed_binary asset_name asset_path mode out_generated_header out_generated_implementation)
	if (NOT EXISTS "${asset_path}")	
		message(FATAL_ERROR "The asset '${asset_name}' does not exist in \"${asset_path}\"")
	endif()

	file(READ "${asset_path}" file_contents HEX)
	string(LENGTH "${file_contents}" file_contents_length)

	string(MAKE_C_IDENTIFIER "${asset_name}" asset_name_identifier)

	math(EXPR file_bytes "${file_contents_length} / 2")
	math(EXPR file_contents_modulo_2 "${file_contents_length} % 2")

	if (NOT file_contents_modulo_2 EQUAL 0)
		message(FATAL_ERROR "File length in hexadecimal must be a multiple of 2")
	endif()

	set(valid_modes "constexpr" "extern")

	if (NOT "${mode}" IN_LIST valid_modes)
		message(FATAL_ERROR "mode '${mode}' is not one of the valid modes: ${valid_modes}")
	endif()
	
	set(bytes_per_line 64)
    string(REPEAT "[0-9a-f]" ${bytes_per_line} column_pattern)
    string(REGEX REPLACE "(${column_pattern})" "\\1\n" code "${file_contents}")

    string(REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\1," code "${code}")

	set(partial_declaration "unsigned char embedded_${asset_name_identifier}[${file_bytes}]")
	set(code "${partial_declaration} = {\n${code}\n};\n")

	set(header "#pragma once\n\n")
	set(implementation "")

	if (mode STREQUAL "constexpr")
		string(APPEND header "#ifndef __cplusplus\n#error \"'constexpr' is a C++ feature\"\n#endif\n\nconstexpr ${code}")
	else()
		string(APPEND header "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\nextern const ${partial_declaration};\n\n#ifdef __cplusplus\n}\n#endif\n")
		string(APPEND implementation "#include \"${asset_name_identifier}.h\"\n\n#ifdef __cplusplus\nextern \"C\" {\n#endif\n\nconst ${code}\n#ifdef __cplusplus\n}\n#endif\n")
	endif()

	set(${out_generated_header} "${header}" PARENT_SCOPE)
	set(${out_generated_implementation} "${implementation}" PARENT_SCOPE)
endfunction()

# The variable is set when including this file
set(_path_to_embed_binary_myself ${CMAKE_CURRENT_LIST_FILE})

# embed_binaries(<generated_target_name>
#	[ASSET NAME <name> PATH <path> [MODE constexpr|extern]]...)
function(embed_binaries target_name)
	if (NOT DEFINED target_name)	
		message(FATAL_ERROR "Missing required argument 'TARGET'")
	endif()

	# Fill these lists with the arguments for each ASSET
	# so that we can loop while zipping over them
	set(asset_NAMEs)
	set(asset_PATHs)
	set(asset_MODEs)

	set(asset_args_to_parse "${ARGN}")
	list(FIND asset_args_to_parse ASSET first_asset_index)

	if (first_asset_index EQUAL -1)
		message(WARNING "No assets to embed in target '${target_name}'")

		# Generate empty library
		add_library("${target_name}" INTERFACE)
		return()
	elseif(NOT first_asset_index EQUAL 0)
		message(FATAL_ERROR "embed_binaries: expected 'ASSET' after <target_name> (\"${target_name}\")")
	endif()
	
	while(asset_args_to_parse) # While not empty
		list(POP_FRONT asset_args_to_parse must_be_ASSET) # Remove "ASSET" from the front
		if (NOT must_be_ASSET STREQUAL "ASSET")
			message(FATAL_ERROR "Bug detected: \"ASSET\" expected, got \"${must_be_ASSET}\". Remaining args: ${asset_args_to_parse}")
		endif()

		list(FIND asset_args_to_parse ASSET asset_arg_count)

		# Current sublist. If ASSET is not found, FIND returns -1,
		# which SUBLIST interprets as taking the list until the end
		list(SUBLIST asset_args_to_parse 0 ${asset_arg_count} current_asset_args)

		# Remaining sublist
		if (asset_arg_count EQUAL -1)
			set(asset_args_to_parse)
		else()
			list(SUBLIST asset_args_to_parse ${asset_arg_count} -1 asset_args_to_parse)
		endif()

		set(asset_options)
		set(asset_required_args NAME PATH)
		set(asset_optional_args MODE)
		set(asset_optional_args_defaults "extern")
		set(asset_args ${asset_required_args} ${asset_optional_args})
		set(asset_list_args)

		cmake_parse_arguments(asset
			"${asset_options}" "${asset_args}" "${asset_list_args}"
			"${current_asset_args}"
		)

		if (asset_UNPARSED_ARGUMENTS)
			foreach(unrecognized IN LISTS asset_UNPARSED_ARGUMENTS)
				message(SEND_ERROR "Unrecognized argument: '${unrecognized}'")
			endforeach()
			message(FATAL_ERROR "embed_binaries: unrecognized argument(s) (see above) for ASSET with args: \"${current_asset_args}\"")
		endif()

		foreach(arg_name IN LISTS asset_required_args)
			if (NOT DEFINED asset_${arg_name})
				message(FATAL_ERROR "ASSET '${arg_name}' missing in ASSET with args: \"${current_asset_args}\"")
			endif()

			list(APPEND asset_${arg_name}s ${asset_${arg_name}})
		endforeach()

		foreach(arg_name default_value IN ZIP_LISTS asset_optional_args asset_optional_args_defaults)
			if (NOT DEFINED asset_${arg_name})
				set(asset_${arg_name} ${default_value})
			endif()

			list(APPEND asset_${arg_name}s ${asset_${arg_name}})
		endforeach()
	endwhile()

	set(library_type OBJECT)
	set(header_visibility PRIVATE)

	set(asset_non_constexpr_modes "${asset_MODEs}")
	list(FILTER asset_non_constexpr_modes EXCLUDE REGEX "^constexpr$")
	if (NOT asset_non_constexpr_modes)
		set(library_type INTERFACE)
		set(header_visibility INTERFACE)
	else()
		enable_language(C)
	endif()

	add_library("${target_name}" "${library_type}")
	#set_target_properties("${target_name}" PROPERTIES LINKER_LANGUAGE C) # CMake seemed to not be able to detect it (?)
	target_include_directories("${target_name}" INTERFACE "${CMAKE_CURRENT_BINARY_DIR}")

	if (NOT asset_non_constexpr_modes)
		target_compile_features("${target_name}" INTERFACE cxx_constexpr)
	endif()

	list(LENGTH asset_NAMEs asset_NAMEs_length)
	list(LENGTH asset_PATHs asset_PATHs_length)
	list(LENGTH asset_MODEs asset_MODEs_length)

	if (NOT ((asset_NAMEs_length EQUAL asset_PATHs_length) AND (asset_NAMEs_length EQUAL asset_MODEs_length)))
		message(FATAL_ERROR "Bug detected: length mismatch\nasset_NAMEs (${asset_NAMEs_length}) = ${asset_NAMEs}\nasset_PATHs (${asset_PATHs_length}) = ${asset_PATHs}\nasset_MODEs (${asset_MODEs_length}) = ${asset_MODEs}")
	endif()

	foreach(asset_NAME asset_PATH asset_MODE IN ZIP_LISTS asset_NAMEs asset_PATHs asset_MODEs)
		string(MAKE_C_IDENTIFIER "${asset_NAME}" asset_name_identifier)

		get_filename_component(asset_PATH ${asset_PATH} ABSOLUTE)

		if (NOT EXISTS "${asset_PATH}")
			message(FATAL_ERROR "The asset '${asset_NAME}' does not exist in \"${asset_PATH}\"")
		endif()

		set(valid_modes "constexpr" "extern")

		if (NOT "${asset_MODE}" IN_LIST valid_modes)
			message(FATAL_ERROR "embed_binaries: MODE '${asset_MODE}' is not one of the valid modes: ${valid_modes}")
		endif()

		set(generated_code_directory "${CMAKE_CURRENT_BINARY_DIR}/embedded")
		set(generated_header_path "${generated_code_directory}/${asset_name_identifier}.h")
		set(generated_implementation_path "${generated_code_directory}/${asset_name_identifier}.c")

		target_sources("${target_name}" "${header_visibility}" "${generated_header_path}")
		if (asset_MODE STREQUAL "constexpr")
			set(generated_asset_files "${generated_header_path}")
		else()
			set(generated_asset_files "${generated_header_path}" "${generated_implementation_path}")
			target_sources("${target_name}" PRIVATE "${generated_implementation_path}")
		endif()

		add_custom_command(OUTPUT ${generated_asset_files}
			COMMAND "${CMAKE_COMMAND}" -E make_directory "${generated_code_directory}"
			COMMAND "${CMAKE_COMMAND}"
				ARGS
					"-Dasset_name=${asset_NAME}"
					"-Dasset_path=${asset_PATH}"
					"-Dmode=${asset_MODE}"
					"-Dgenerated_header_path=${generated_header_path}"
					"-Dgenerated_implementation_path=${generated_implementation_path}"
					-P "${_path_to_embed_binary_myself}"
			DEPENDS "${asset_PATH}"
			COMMENT "Embedding binary asset '${asset_NAME}' (\"${asset_PATH}\")..."
			VERBATIM
		)
	endforeach()
endfunction()

function(write_embedded_binary_code asset_name asset_path mode generated_header_path generated_implementation_path)
	generate_code_to_embed_binary("${asset_name}" "${asset_path}" "${mode}" generated_header generated_implementation)

	file(WRITE "${generated_header_path}" "${generated_header}")

	if (generated_implementation STREQUAL "")
		if (EXISTS "${generated_implementation_path}")
			file(REMOVE "${generated_implementation_path}")
		endif()
	else()
		file(WRITE "${generated_implementation_path}" "${generated_implementation}")
	endif()
endfunction()

# Running in script mode
# https://stackoverflow.com/questions/51427538/cmake-test-if-i-am-in-scripting-mode
if(CMAKE_SCRIPT_MODE_FILE AND NOT CMAKE_PARENT_LIST_FILE)
    foreach(variable "asset_name" "asset_path" "mode" "generated_header_path" "generated_implementation_path")
        if (NOT DEFINED ${variable})
            message(FATAL_ERROR "'${variable}' is not defined")
        endif()
    endforeach()

    write_embedded_binary_code("${asset_name}" "${asset_path}" "${mode}" "${generated_header_path}" "${generated_implementation_path}")
endif()
