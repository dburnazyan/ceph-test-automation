args <- commandArgs(trailingOnly = TRUE)

raw_data_file = args[1]
base_out_dir = args[2]

data = read.csv(raw_data_file, header=TRUE)

out_file = paste(base_out_dir, "/cluster_bandwidth.png", sep="")
png(out_file, width=900)
plot(data$Bandwidth/(1024*1024), main="Ceph cluster bandwidth(MB/s)", type='l')
grid(nx = 50, ny = 20)
dev.off()
