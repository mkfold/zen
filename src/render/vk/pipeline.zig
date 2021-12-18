const std = @import("std");

const check_success = @import("../vk.zig").check_success;
const c = @import("../../c.zig");
const cc = @import("../../cc.zig");

usingnamespace @import("../vertex.zig");

pub fn init_shader(logical_device: c.VkDevice, src: []const u8) !c.VkShaderModule {
    const shader_info = c.VkShaderModuleCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .pCode = @ptrCast([*c]const u32, @alignCast(4, src.ptr)),
        .codeSize = src.len,
    };
    var shader_module: c.VkShaderModule = undefined;
    check_success(c.vkCreateShaderModule(
        logical_device,
        &shader_info,
        null,
        &shader_module,
    )) catch return error.CreateShaderModuleFailed;

    return shader_module;
}

pub fn init_static_pipeline(
    logical_device: c.VkDevice,
    swapchain_extent: c.VkExtent2D,
    render_pass: c.VkRenderPass,
    static_pipeline_layout: *c.VkPipelineLayout,
    pipeline: *c.VkPipeline,
) !void {
    var vert_shader_src = try cc.read_file(std.heap.page_allocator, "assets/shaders/static_vert.spv");
    defer std.heap.page_allocator.free(vert_shader_src);

    var frag_shader_src = try cc.read_file(std.heap.page_allocator, "assets/shaders/static_frag.spv");
    defer std.heap.page_allocator.free(frag_shader_src);

    var vert_module = try init_shader(logical_device, vert_shader_src);
    var frag_module = try init_shader(logical_device, frag_shader_src);

    const vert_stage_info = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .pNext = null,
        .stage = c.VkShaderStageFlagBits.VK_SHADER_STAGE_VERTEX_BIT,
        .module = vert_module,
        .pName = "main",
        .pSpecializationInfo = null,
        .flags = 0,
    };

    const frag_stage_info = c.VkPipelineShaderStageCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .pNext = null,
        .stage = c.VkShaderStageFlagBits.VK_SHADER_STAGE_FRAGMENT_BIT,
        .module = frag_module,
        .pName = "main",
        .pSpecializationInfo = null,
        .flags = 0,
    };

    const shader_stages = [_]c.VkPipelineShaderStageCreateInfo{
        vert_stage_info,
        frag_stage_info,
    };

    const vert_binding_desc = c.VkVertexInputBindingDescription{
        .binding = 0,
        .stride = @sizeOf(StaticMeshVertex),
        .inputRate = c.VkVertexInputRate.VK_VERTEX_INPUT_RATE_VERTEX,
    };

    // NOTE: if the vertex struct changes, the following will likely also have
    // to change
    var vert_attrib_descs: [5]c.VkVertexInputAttributeDescription = undefined;

    // position
    vert_attrib_descs[0] = c.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 0,
        .format = c.VkFormat.VK_FORMAT_R32G32B32_SFLOAT,
        .offset = @byteOffsetOf(StaticMeshVertex, "position"),
    };

    // uv coordinates
    vert_attrib_descs[1] = c.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 1,
        .format = c.VkFormat.VK_FORMAT_R32G32_SFLOAT,
        .offset = @byteOffsetOf(StaticMeshVertex, "tex_coord"),
    };

    // normal
    vert_attrib_descs[2] = c.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 2,
        .format = c.VkFormat.VK_FORMAT_R32G32B32_SFLOAT,
        .offset = @byteOffsetOf(StaticMeshVertex, "normal"),
    };

    // tangent
    vert_attrib_descs[3] = c.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 3,
        .format = c.VkFormat.VK_FORMAT_R32G32B32A32_SFLOAT,
        .offset = @byteOffsetOf(StaticMeshVertex, "tangent"),
    };

    // color
    vert_attrib_descs[4] = c.VkVertexInputAttributeDescription{
        .binding = 0,
        .location = 4,
        .format = c.VkFormat.VK_FORMAT_R8G8B8A8_UINT,
        .offset = @byteOffsetOf(StaticMeshVertex, "color"),
    };

    const vert_input_state = c.VkPipelineVertexInputStateCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .vertexBindingDescriptionCount = 1,
        .pVertexBindingDescriptions = &vert_binding_desc,
        .vertexAttributeDescriptionCount = 5,
        .pVertexAttributeDescriptions = &vert_attrib_descs,
    };

    const input_asm_state = c.VkPipelineInputAssemblyStateCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .topology = c.VkPrimitiveTopology.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = c.VK_FALSE,
    };

    const viewport = c.VkViewport{
        .x = 0,
        .y = 0,
        .width = @intToFloat(f32, swapchain_extent.width),
        .height = @intToFloat(f32, swapchain_extent.height),
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };

    const scissor = c.VkRect2D{
        .offset = c.VkOffset2D{ .x = 0, .y = 0 },
        .extent = swapchain_extent,
    };

    const vp_state = c.VkPipelineViewportStateCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .viewportCount = 1,
        .pViewports = &viewport,
        .scissorCount = 1,
        .pScissors = &scissor,
    };

    const rasterizer_state = c.VkPipelineRasterizationStateCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .depthClampEnable = c.VK_FALSE,
        .rasterizerDiscardEnable = c.VK_FALSE,
        .polygonMode = c.VkPolygonMode.VK_POLYGON_MODE_FILL,
        .lineWidth = 1.0,
        .cullMode = c.VK_CULL_MODE_BACK_BIT,
        .frontFace = c.VkFrontFace.VK_FRONT_FACE_CLOCKWISE,
        .depthBiasEnable = c.VK_FALSE,
        .depthBiasConstantFactor = 0.0,
        .depthBiasClamp = 0.0,
        .depthBiasSlopeFactor = 0.0,
    };

    // TODO: enable multisampling for MSAA
    const ms_state = c.VkPipelineMultisampleStateCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .rasterizationSamples = c.VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
        .sampleShadingEnable = c.VK_FALSE,
        .minSampleShading = 1.0,
        .pSampleMask = null,
        .alphaToCoverageEnable = c.VK_FALSE,
        .alphaToOneEnable = c.VK_FALSE,
    };

    const color_blend_attachment = c.VkPipelineColorBlendAttachmentState{
        .blendEnable = c.VK_FALSE,
        .srcColorBlendFactor = c.VkBlendFactor.VK_BLEND_FACTOR_ONE,
        .dstColorBlendFactor = c.VkBlendFactor.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .colorBlendOp = c.VkBlendOp.VK_BLEND_OP_ADD,
        .srcAlphaBlendFactor = c.VkBlendFactor.VK_BLEND_FACTOR_ONE,
        .dstAlphaBlendFactor = c.VkBlendFactor.VK_BLEND_FACTOR_ZERO,
        .alphaBlendOp = c.VkBlendOp.VK_BLEND_OP_ADD,
        .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT |
            c.VK_COLOR_COMPONENT_G_BIT |
            c.VK_COLOR_COMPONENT_B_BIT |
            c.VK_COLOR_COMPONENT_A_BIT,
    };

    const color_blend_state = c.VkPipelineColorBlendStateCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .logicOpEnable = c.VK_FALSE,
        .logicOp = c.VkLogicOp.VK_LOGIC_OP_COPY,
        .attachmentCount = 1,
        .pAttachments = &color_blend_attachment,
        .blendConstants = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
    };

    const depth_stencil = c.VkPipelineDepthStencilStateCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .depthTestEnable = c.VK_TRUE,
        .depthWriteEnable = c.VK_TRUE,
        .depthCompareOp = c.VkCompareOp.VK_COMPARE_OP_LESS,
        .depthBoundsTestEnable = c.VK_FALSE,
        .minDepthBounds = 0.0,
        .maxDepthBounds = 1.0,
        .stencilTestEnable = c.VK_FALSE,
        .front = std.mem.zeroes(c.VkStencilOpState),
        .back = std.mem.zeroes(c.VkStencilOpState),
    };

    const pipeline_layout_info = c.VkPipelineLayoutCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .setLayoutCount = 0,
        .pSetLayouts = null,
        .pushConstantRangeCount = 0,
        .pPushConstantRanges = null,
    };

    try check_success(c.vkCreatePipelineLayout(
        logical_device,
        &pipeline_layout_info,
        null,
        static_pipeline_layout,
    ));

    const pipeline_info = c.VkGraphicsPipelineCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .stageCount = 2,
        .pStages = &shader_stages,
        .pVertexInputState = &vert_input_state,
        .pInputAssemblyState = &input_asm_state,
        .pTessellationState = null,
        .pViewportState = &vp_state,
        .pRasterizationState = &rasterizer_state,
        .pMultisampleState = &ms_state,
        .pDepthStencilState = &depth_stencil,
        .pColorBlendState = &color_blend_state,
        .pDynamicState = null,
        .layout = static_pipeline_layout.*,
        .renderPass = render_pass,
        .subpass = 0,
        .basePipelineHandle = null,
        .basePipelineIndex = -1,
    };

    try check_success(c.vkCreateGraphicsPipelines(
        logical_device,
        null,
        1,
        &pipeline_info,
        null,
        pipeline,
    ));

    c.vkDestroyShaderModule(logical_device, frag_module, null);
    c.vkDestroyShaderModule(logical_device, vert_module, null);
}
