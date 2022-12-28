--[[
Example lua script demonstrating the Slurm job_submit/lua interface.
This is only an example, not meant for use in its current form.
For use, this script should be copied into a file name "job_submit.lua"
in the same directory as the Slurm configuration file, slurm.conf.
--]]

function slurm_job_submit(job_desc, part_list, submit_uid)
    slurm.log_user("slurm_job_submit: job from uid %u", submit_uid)
    slurm.log_user("slurm_job_submit: job_desc.name %s", job_desc.name)
    slurm.log_user("slurm_job_submit: job_desc.script %s", job_desc.script)
    slurm.log_user("slurm_job_submit: job_desc.work_dir %s", job_desc.work_dir)
    slurm.log_user("slurm_job_submit: job_desc.environment %s", job_desc.environment)
    local numitems = 0
    for k, v in pairs(job_desc.environment) do
            numitems = numitems + 1
            slurm.log_info("slurm_job_submit: job_desc.environment %s : %s", k, v)
    end
    slurm.log_user("slurm_job_submit: job_desc.environment %s", numitems)
    local command = "touch " .. job_desc.work_dir .. "/hello_world_.txt"
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    slurm.log_user("slurm_job_submit: %s", result)
    return slurm.SUCCESS
end

function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)
    return slurm.SUCCESS
end

slurm.log_info("job submit plugin initialized")
return slurm.SUCCESS

