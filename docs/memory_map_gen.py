import csv
from pathlib import Path

from topwrap.cli import load_modules_from_repos
from topwrap.frontend.yaml.frontend import YamlFrontend


def _underscore_hex(hex: str) -> str:
    """Converts a hex value to a string with underscores every 4 characters"""
    groups = []
    while hex:
        groups.append(hex[-4:])
        hex = hex[:-4]
    groups.reverse()
    return f"0x{'_'.join(groups)}"


def _hex_to_str(val: int) -> str:
    """Formats hex to str which has 8 characters and is capitalized"""
    hex_str = f"{val:x}"
    if len(hex_str) < 8:
        hex_str = "0" * (8 - len(hex_str)) + hex_str
    return hex_str.upper()


def format_hex(val: int) -> str:
    """
    Converts a hex value to meed demands of memory map format which includes:
        * Capitalized ascii representation of the hex value
        * 0x prefix
        * Underscores every 4 characters
        * All addresses are 8 characters long
    """
    hex_str = _hex_to_str(val)
    return _underscore_hex(hex_str)


def design_component_to_mmap_name(name: str) -> str:
    return {
        "lmem0": "Memory for core 0",
        "lmem1": "Memory for core 1",
        "axi_bridge": "UART",
        "i_axi_cdc_lsu": "I3C core",
    }[name]


def generate_map(design_file: Path, output: Path):
    repo_modules, _ = load_modules_from_repos()

    frontend = YamlFrontend(repo_modules)
    module = frontend.parse_design_file(design_file).modules[0]

    assert module.design is not None
    design = module.design
    design.update_interconnects_from_memory_maps()

    subordinates = {
        "VeeR EL2 reserved space": {"address": 0x0, "size": 0x2000_0000}
    }
    intr = design.interconnects.find_by_name_or_error("axi_interconnect1")
    for intf, params in intr.subordinates.items():
        name = design_component_to_mmap_name(intf.resolve().instance.name)

        subordinates[name] = {
            "address": int(params.address.value),
            "size": int(params.size.value),
        }

    output.parent.mkdir(exist_ok=True)
    with open(output, "w", newline="") as memory_map_csv:
        table_columns = ["Start Address", "End Address", "Size", "Type"]
        writer = csv.DictWriter(memory_map_csv, fieldnames=table_columns)
        writer.writeheader()
        for peripheral, map_location in subordinates.items():
            start_address = map_location["address"]
            size = map_location["size"]
            end_address = start_address + size - 1
            writer.writerow(
                {
                    table_columns[0]: start_address,
                    table_columns[1]: end_address,
                    table_columns[2]: size,
                    table_columns[3]: peripheral,
                }
            )
        print(f"Memory map generated successfully for {design_file}")


if __name__ == "__main__":
    docs_dir = Path(__file__).resolve().parent
    designs_dir = docs_dir.parent / "topwrap"
    generate_map(
        designs_dir / "design-dualcore.yaml",
        docs_dir / "build/memory_map_dualcore.csv",
    )
    generate_map(
        designs_dir / "design-singlecore.yaml",
        docs_dir / "build/memory_map_singlecore.csv",
    )
