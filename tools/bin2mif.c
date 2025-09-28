// Enhanced C99 Binary to MIF Converter with 96-Block Support
// Supports new-soc-mif simulation with 48KB memory space
// Generates 96 × 512-byte blocks for M4K Block RAM simulation

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <getopt.h>
#include <sys/stat.h>
#include <time.h>

// Version information
#define VERSION "1.1.0"
#define PROGRAM_NAME "bin2mif"

// Enhanced configuration for 96-block support
#define DEFAULT_BLOCK_SIZE 512       // M4K block size (512 bytes = 128 words × 32-bit)
#define DEFAULT_BLOCK_TYPE "m4k"     // M4K blocks for Cyclone II
#define DEFAULT_WORD_SIZE 32         // 32-bit words
#define MAX_BLOCKS 128               // Maximum number of blocks (supports 96-block)
#define MAX_FILENAME 256
#define DEFAULT_FILL_PATTERN 0x00000013  // RISC-V NOP instruction
#define DEFAULT_TOTAL_BLOCKS 96      // 48KB ÷ 512 bytes = 96 blocks
#define DEFAULT_TOTAL_SIZE 49152     // 48KB total memory space

// Configuration structure
typedef struct {
    char input_file[MAX_FILENAME];
    char output_pattern[MAX_FILENAME];
    int block_size;
    char block_type[16];
    int word_size;
    int max_blocks;
    int verbose;
    int total_blocks;        // Force specific number of output blocks
    int total_size;          // Force specific total memory size
    uint32_t fill_pattern;   // Fill pattern for unused blocks
    int hex_format;          // Output simple hex format for simulation
    int single_mif;          // Generate single complete MIF file instead of blocks
} config_t;

// Block information structure
typedef struct {
    int block_num;
    int size_bytes;
    int size_words;
    char filename[MAX_FILENAME];
} block_info_t;

// Print usage information
void print_usage(const char *program_name) {
    printf("Usage: %s [OPTIONS] -i INPUT_FILE -o OUTPUT_PATTERN\n\n", program_name);
    printf("Enhanced binary to MIF converter with 96-block support for new-soc-mif\n\n");
    printf("Required Arguments:\n");
    printf("  -i, --input FILE         Input binary file\n");
    printf("  -o, --output PATTERN     Output MIF pattern (e.g., firmware_%%02d.mif)\n\n");
    printf("Optional Arguments:\n");
    printf("  -s, --block-size SIZE    Block size in bytes (default: %d)\n", DEFAULT_BLOCK_SIZE);
    printf("  -t, --block-type TYPE    Block type: m4k, m9k, m144k (default: %s)\n", DEFAULT_BLOCK_TYPE);
    printf("  -w, --word-size BITS     Word size in bits: 8, 16, 32 (default: %d)\n", DEFAULT_WORD_SIZE);
    printf("  -m, --max-blocks NUM     Maximum number of blocks (default: %d)\n", MAX_BLOCKS);
    printf("      --total-blocks NUM   Force specific number of output blocks (default: %d)\n", DEFAULT_TOTAL_BLOCKS);
    printf("      --total-size SIZE    Force specific total memory size (default: %d)\n", DEFAULT_TOTAL_SIZE);
    printf("      --fill-pattern HEX   Fill pattern for unused blocks (default: 0x%08X)\n", DEFAULT_FILL_PATTERN);
    printf("  -v, --verbose            Verbose output\n");
    printf("      --hex                Output simple hex format for simulation (compatible with $readmemh)\n");
    printf("      --single-mif         Generate single complete MIF file instead of blocks\n");
    printf("  -h, --help               Show this help\n");
    printf("      --version            Show version information\n\n");
    printf("Examples:\n");
    printf("  # Generate 96 MIF files for new-soc-mif simulation:\n");
    printf("  %s -i firmware.bin -o firmware_%%02d.mif --total-blocks 96\n\n", program_name);
    printf("  # Custom block size with NOP fill:\n");
    printf("  %s -i firmware.bin -o firmware_%%02d.mif -s 512 --fill-pattern 0x13\n\n", program_name);
    printf("  # Generate single complete MIF file (for FPGA synthesis):\n");
    printf("  %s -i firmware.bin -o firmware.mif --single-mif --total-size 49152\n\n", program_name);
}

// Initialize configuration with defaults
void init_config(config_t *config) {
    memset(config, 0, sizeof(config_t));
    config->block_size = DEFAULT_BLOCK_SIZE;
    strncpy(config->block_type, DEFAULT_BLOCK_TYPE, sizeof(config->block_type) - 1);
    config->word_size = DEFAULT_WORD_SIZE;
    config->max_blocks = MAX_BLOCKS;
    config->total_blocks = DEFAULT_TOTAL_BLOCKS;
    config->total_size = DEFAULT_TOTAL_SIZE;
    config->fill_pattern = DEFAULT_FILL_PATTERN;
    config->verbose = 0;
}

// Generate single MIF file
int generate_mif_file(const char *filename, const uint8_t *data, int data_size,
                     int block_num, int block_size, int word_size, uint32_t fill_pattern,
                     int verbose, int hex_format) {
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        fprintf(stderr, "Error: Cannot create MIF file: %s\n", filename);
        return -1;
    }

    int words_per_block = block_size / (word_size / 8);

    if (verbose) {
        printf("Creating block %d: %s (%d words)\n", block_num, filename, words_per_block);
    }

    if (hex_format) {
        // Simple hex format for simulation - no header, just hex data
        if (verbose) {
            fprintf(fp, "// Simple hex format for block %d\n", block_num);
        }
    } else {
        // Write MIF header for FPGA synthesis
        fprintf(fp, "-- Auto-generated MIF file for Block %d\n", block_num);
        fprintf(fp, "-- Generated by %s version %s\n", PROGRAM_NAME, VERSION);
        fprintf(fp, "-- Block size: %d bytes, %d words\n", block_size, words_per_block);
        fprintf(fp, "-- Fill pattern: 0x%08X\n", fill_pattern);
        time_t now = time(NULL);
        fprintf(fp, "-- Generated: %s\n", ctime(&now));
        fprintf(fp, "DEPTH = %d;\n", words_per_block);
        fprintf(fp, "WIDTH = %d;\n", word_size);
        fprintf(fp, "ADDRESS_RADIX = HEX;\n");
        fprintf(fp, "DATA_RADIX = HEX;\n");
        fprintf(fp, "CONTENT\n");
        fprintf(fp, "BEGIN\n");
    }

    // Write data words
    for (int word = 0; word < words_per_block; word++) {
        int byte_offset = (block_num * block_size) + (word * (word_size / 8));
        uint32_t word_data = fill_pattern;  // Default fill

        // If we have actual data for this word
        if (byte_offset < data_size) {
            word_data = 0;
            for (int byte = 0; byte < (word_size / 8) && (byte_offset + byte) < data_size; byte++) {
                word_data |= ((uint32_t)data[byte_offset + byte]) << (byte * 8);
            }
        }

        if (hex_format) {
            // Simple hex format: just the hex value, one per line
            fprintf(fp, "%08X\n", word_data);
        } else {
            // MIF format: address : data ;
            fprintf(fp, "%04X : %08X;\n", word, word_data);
        }
    }

    if (!hex_format) {
        fprintf(fp, "END;\n");
    }
    fclose(fp);
    return 0;
}

// Generate single complete MIF file
int generate_single_mif_file(const char *filename, const uint8_t *data, int data_size,
                             int total_size, int word_size, uint32_t fill_pattern, int verbose) {
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        fprintf(stderr, "Error: Cannot create MIF file: %s\n", filename);
        return -1;
    }

    int total_words = total_size / (word_size / 8);

    if (verbose) {
        printf("Creating single MIF file: %s (%d words, %d bytes)\n", filename, total_words, total_size);
    }

    // Write MIF header
    fprintf(fp, "-- Single complete MIF file\n");
    fprintf(fp, "-- Generated by %s version %s\n", PROGRAM_NAME, VERSION);
    fprintf(fp, "-- Total size: %d bytes, %d words\n", total_size, total_words);
    fprintf(fp, "-- Fill pattern: 0x%08X\n", fill_pattern);
    time_t now = time(NULL);
    fprintf(fp, "-- Generated: %s\n", ctime(&now));
    fprintf(fp, "DEPTH = %d;\n", total_words);
    fprintf(fp, "WIDTH = %d;\n", word_size);
    fprintf(fp, "ADDRESS_RADIX = HEX;\n");
    fprintf(fp, "DATA_RADIX = HEX;\n");
    fprintf(fp, "CONTENT\n");
    fprintf(fp, "BEGIN\n");

    // Write all data words
    for (int word = 0; word < total_words; word++) {
        int byte_offset = word * (word_size / 8);
        uint32_t word_data = fill_pattern;  // Default fill

        // If we have actual data for this word
        if (byte_offset < data_size) {
            word_data = 0;
            for (int byte = 0; byte < (word_size / 8) && (byte_offset + byte) < data_size; byte++) {
                word_data |= ((uint32_t)data[byte_offset + byte]) << (byte * 8);
            }
        }

        // MIF format: address : data ;
        fprintf(fp, "%04X : %08X;\n", word, word_data);
    }

    fprintf(fp, "END;\n");
    fclose(fp);
    return 0;
}

// Main conversion function
int convert_bin_to_mif(const config_t *config) {
    // Read input binary file
    FILE *fp = fopen(config->input_file, "rb");
    if (!fp) {
        fprintf(stderr, "Error: Cannot open input file: %s\n", config->input_file);
        return -1;
    }

    fseek(fp, 0, SEEK_END);
    long file_size = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    uint8_t *data = malloc(file_size);
    if (!data) {
        fprintf(stderr, "Error: Cannot allocate memory for file data\n");
        fclose(fp);
        return -1;
    }

    size_t bytes_read = fread(data, 1, file_size, fp);
    fclose(fp);

    if (bytes_read != (size_t)file_size) {
        fprintf(stderr, "Error: Could not read complete file\n");
        free(data);
        return -1;
    }

    if (config->verbose) {
        printf("Input file: %s (%ld bytes)\n", config->input_file, file_size);
        if (config->single_mif) {
            printf("Generating single MIF file with %d bytes total\n", config->total_size);
        } else {
            printf("Generating %d blocks of %d bytes each\n", config->total_blocks, config->block_size);
            printf("Total memory space: %d bytes\n", config->total_blocks * config->block_size);
        }
    }

    // Handle single MIF file generation
    if (config->single_mif) {
        if (generate_single_mif_file(config->output_pattern, data, file_size,
                                   config->total_size, config->word_size,
                                   config->fill_pattern, config->verbose) != 0) {
            fprintf(stderr, "Error generating single MIF file\n");
            free(data);
            return -1;
        }

        free(data);
        if (config->verbose) {
            printf("Successfully generated single MIF file: %s\n", config->output_pattern);
        }
        return 0;
    }

    // Generate MIF files
    block_info_t blocks[MAX_BLOCKS];
    for (int i = 0; i < config->total_blocks && i < MAX_BLOCKS; i++) {
        blocks[i].block_num = i;
        blocks[i].size_bytes = config->block_size;
        blocks[i].size_words = config->block_size / (config->word_size / 8);

        snprintf(blocks[i].filename, MAX_FILENAME, config->output_pattern, i);

        if (generate_mif_file(blocks[i].filename, data, file_size, i,
                             config->block_size, config->word_size,
                             config->fill_pattern, config->verbose, config->hex_format) != 0) {
            fprintf(stderr, "Error generating block %d\n", i);
            free(data);
            return -1;
        }
    }

    free(data);

    if (config->verbose) {
        printf("Successfully generated %d MIF files\n", config->total_blocks);
    }

    return 0;
}

// Parse command line arguments
int parse_arguments(int argc, char *argv[], config_t *config) {
    static struct option long_options[] = {
        {"input",         required_argument, 0, 'i'},
        {"output",        required_argument, 0, 'o'},
        {"block-size",    required_argument, 0, 's'},
        {"block-type",    required_argument, 0, 't'},
        {"word-size",     required_argument, 0, 'w'},
        {"max-blocks",    required_argument, 0, 'm'},
        {"total-blocks",  required_argument, 0, 257},
        {"total-size",    required_argument, 0, 258},
        {"fill-pattern",  required_argument, 0, 259},
        {"hex",           no_argument,       0, 260},
        {"single-mif",    no_argument,       0, 261},
        {"verbose",       no_argument,       0, 'v'},
        {"help",          no_argument,       0, 'h'},
        {"version",       no_argument,       0, 256},
        {0, 0, 0, 0}
    };

    int option_index = 0;
    int c;

    while ((c = getopt_long(argc, argv, "i:o:s:t:w:m:vh", long_options, &option_index)) != -1) {
        switch (c) {
            case 'i':
                strncpy(config->input_file, optarg, MAX_FILENAME - 1);
                break;
            case 'o':
                strncpy(config->output_pattern, optarg, MAX_FILENAME - 1);
                break;
            case 's':
                config->block_size = atoi(optarg);
                if (config->block_size <= 0) {
                    fprintf(stderr, "Error: Invalid block size: %s\n", optarg);
                    return -1;
                }
                break;
            case 't':
                strncpy(config->block_type, optarg, sizeof(config->block_type) - 1);
                break;
            case 'w':
                config->word_size = atoi(optarg);
                if (config->word_size != 8 && config->word_size != 16 && config->word_size != 32) {
                    fprintf(stderr, "Error: Invalid word size: %s (must be 8, 16, or 32)\n", optarg);
                    return -1;
                }
                break;
            case 'm':
                config->max_blocks = atoi(optarg);
                if (config->max_blocks <= 0 || config->max_blocks > MAX_BLOCKS) {
                    fprintf(stderr, "Error: Invalid max blocks: %s (must be 1-%d)\n", optarg, MAX_BLOCKS);
                    return -1;
                }
                break;
            case 257: // --total-blocks
                config->total_blocks = atoi(optarg);
                if (config->total_blocks <= 0 || config->total_blocks > MAX_BLOCKS) {
                    fprintf(stderr, "Error: Invalid total blocks: %s (must be 1-%d)\n", optarg, MAX_BLOCKS);
                    return -1;
                }
                break;
            case 258: // --total-size
                config->total_size = atoi(optarg);
                if (config->total_size <= 0) {
                    fprintf(stderr, "Error: Invalid total size: %s\n", optarg);
                    return -1;
                }
                break;
            case 259: // --fill-pattern
                config->fill_pattern = strtoul(optarg, NULL, 0);
                break;
            case 260: // --hex
                config->hex_format = 1;
                break;
            case 261: // --single-mif
                config->single_mif = 1;
                break;
            case 'v':
                config->verbose = 1;
                break;
            case 'h':
                print_usage(argv[0]);
                exit(0);
            case 256: // --version
                printf("%s version %s\n", PROGRAM_NAME, VERSION);
                exit(0);
            case '?':
                return -1;
            default:
                abort();
        }
    }

    // Validate required arguments
    if (strlen(config->input_file) == 0) {
        fprintf(stderr, "Error: Input file (-i) is required\n");
        return -1;
    }

    if (strlen(config->output_pattern) == 0) {
        fprintf(stderr, "Error: Output pattern (-o) is required\n");
        return -1;
    }

    return 0;
}

int main(int argc, char *argv[]) {
    config_t config;
    init_config(&config);

    if (parse_arguments(argc, argv, &config) != 0) {
        print_usage(argv[0]);
        return 1;
    }

    if (convert_bin_to_mif(&config) != 0) {
        return 1;
    }

    return 0;
}