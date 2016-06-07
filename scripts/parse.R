args <- commandArgs(trailingOnly = TRUE)

raw_data_file = args[1]
base_out_dir = args[2]

data = read.csv(raw_data_file, header=TRUE)

out_file = paste(base_out_dir, "/mean", sep="")
sink(out_file)
cat(mean(data$Bandwidth[121:361]/(1024*1024)))
sink()

out_file = paste(base_out_dir, "/deviation", sep="")
sink(out_file)
cat(sd(data$Bandwidth[121:361]/(1024*1024)))
sink()

out_file = paste(base_out_dir, "/min", sep="")
sink(out_file)
cat(min(data$Bandwidth[121:361]/(1024*1024)))
sink()

out_file = paste(base_out_dir, "/max", sep="")
sink(out_file)
cat(max(data$Bandwidth[121:361]/(1024*1024)))
sink()
